#!/usr/bin/env bash
# /usr/local/sbin/deploy-hako-runtime.sh
#
# Deploy versionado e reversível do runtime HAKO Creative num commit específico.
# PROPRIEDADE: root:root, modo 0755. NÃO editável pelo usuário hako-deploy.
# INVOCAÇÃO (única permitida ao hako-deploy via sudoers):
#     sudo /usr/local/sbin/deploy-hako-runtime.sh <sha40> [--enable-telegram]
#
# Fronteiras (não viola):
#  - nunca roda o runtime como root (serviços usam User=hako-creative);
#  - nunca faz `git pull` sobre diretório de produção mutável (clona por SHA em tmp);
#  - nunca lê segredos do GitHub: DATABASE_URL/tokens vêm só de /etc/hako-creative/*.env;
#  - nunca reinicia Hermes, n8n, PostgreSQL ou serviços não relacionados;
#  - nunca remove releases além da retenção (mantém >= KEEP);
#  - receiver Telegram só reinicia com --enable-telegram explícito.
set -euo pipefail
umask 027

REPO_URL="https://github.com/Lucasdoreac/hako-creative-intelligence.git"
SRV=/srv/hako-creative
RELEASES="$SRV/releases"
CURRENT="$SRV/current"
RUNTIME_USER=hako-creative
API_UNIT=hako-creative-api.service
WORKER_UNIT=hako-creative-worker.service
TELEGRAM_UNIT=hako-telegram-receiver.service
RUNTIME_ENV=/etc/hako-creative/runtime.env
HEALTH_URL="http://127.0.0.1:8099/health"   # rota real: app/server.py -> GET /health
KEEP=5

log(){ printf '[deploy %s] %s\n' "$(date -u +%FT%TZ)" "$*"; }
die(){ log "ERRO: $*"; exit 1; }

[ "$(id -u)" -eq 0 ] || die "precisa rodar como root (via sudo)"

SHA="${1:-}"; [ -n "$SHA" ] || die "uso: $0 <sha40> [--enable-telegram]"; shift
ENABLE_TELEGRAM=0
for a in "$@"; do case "$a" in
  --enable-telegram) ENABLE_TELEGRAM=1 ;;
  *) die "flag desconhecida: $a" ;;
esac; done

# (2) valida formato do SHA — 40 hex, sem espaço para branch/tag/ref arbitrária
[[ "$SHA" =~ ^[0-9a-f]{40}$ ]] || die "SHA invalido (esperado 40 hex minusculos)"
[ -f "$RUNTIME_ENV" ] || die "$RUNTIME_ENV ausente — rode o instalador/preflight primeiro"

# (3) diretório temporário isolado
TMP="$(mktemp -d /tmp/hako-deploy.XXXXXX)"
cleanup(){ rm -rf "$TMP"; }
trap cleanup EXIT

# (4)(5) baixa o repositório esperado NAQUELE SHA e confirma que o commit existe
log "buscando $REPO_URL @ ${SHA:0:12}"
git -C "$TMP" init -q
git -C "$TMP" remote add origin "$REPO_URL"
git -C "$TMP" fetch -q --depth 1 origin "$SHA" || die "commit nao encontrado no repo esperado"
git -C "$TMP" checkout -q FETCH_HEAD
[ "$(git -C "$TMP" rev-parse HEAD)" = "$SHA" ] || die "HEAD != SHA solicitado"

# (6) verificação mínima de import num venv descartável (sem segredos, sem DB)
log "smoke de import (venv descartavel)"
python3 -m venv "$TMP/.venv"
"$TMP/.venv/bin/pip" install -q --upgrade pip >/dev/null
"$TMP/.venv/bin/pip" install -q -r "$TMP/requirements.txt" >/dev/null
( cd "$TMP" && "$TMP/.venv/bin/python" -c "import app.server, app.runtime_api, app.control_intent, pipeline.regeneration" ) \
  || die "smoke de import falhou"

# (8) cria release imutável /srv/hako-creative/releases/<timestamp>-<sha12>
TS="$(date -u +%Y%m%dT%H%M%SZ)"
REL="$RELEASES/${TS}-${SHA:0:12}"
mkdir -p "$REL"
rsync -a --delete --exclude='.git' --exclude='.venv' "$TMP"/ "$REL"/
chown -R "$RUNTIME_USER":"$RUNTIME_USER" "$REL"

# (9) venv próprio do release, como usuário de runtime (nunca root)
log "instalando venv do release como $RUNTIME_USER"
sudo -u "$RUNTIME_USER" python3 -m venv "$REL/.venv"
sudo -u "$RUNTIME_USER" "$REL/.venv/bin/pip" install -q --upgrade pip >/dev/null
sudo -u "$RUNTIME_USER" "$REL/.venv/bin/pip" install -q -r "$REL/requirements.txt" >/dev/null

# guarda alvo anterior para rollback ANTES de trocar
PREV="$(readlink -f "$CURRENT" 2>/dev/null || true)"

# (10) migrations idempotentes com ON_ERROR_STOP; DATABASE_URL só do env local, nunca ecoado
log "aplicando migrations (ON_ERROR_STOP)"
if ! sudo -u "$RUNTIME_USER" bash -eu -c '
      set -a; . "'"$RUNTIME_ENV"'"; set +a
      for f in $(ls "'"$REL"'"/db/migrations/*.sql 2>/dev/null | sort); do
        echo "[migration] $(basename "$f")"
        psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f "$f" || exit 1
      done'; then
  die "migration falhou — release NAO promovido; producao intacta em ${PREV:-nenhum}"
fi

# (11) troca de symlink ATÔMICA
log "promovendo release (symlink atomico)"
ln -sfn "$REL" "$SRV/.current.new"
mv -Tf "$SRV/.current.new" "$CURRENT"

# (12) reinicia SOMENTE API + worker (+ receiver se explicitamente habilitado)
log "reiniciando API + worker"
systemctl restart "$API_UNIT" "$WORKER_UNIT"
if [ "$ENABLE_TELEGRAM" -eq 1 ]; then log "reiniciando receiver Telegram (habilitado)"; systemctl restart "$TELEGRAM_UNIT"; fi

# (13) health checks: systemd + endpoint local + import + conexão PG
health_ok(){
  systemctl is-active --quiet "$API_UNIT"    || { log "api inativa"; return 1; }
  systemctl is-active --quiet "$WORKER_UNIT" || { log "worker inativo"; return 1; }
  curl -fsS --max-time 10 "$HEALTH_URL" >/dev/null || { log "health endpoint falhou"; return 1; }
  sudo -u "$RUNTIME_USER" "$CURRENT/.venv/bin/python" -c "import app.server" || { log "import pos-deploy falhou"; return 1; }
  sudo -u "$RUNTIME_USER" bash -eu -c 'set -a; . "'"$RUNTIME_ENV"'"; set +a; psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -Atqc "select 1" >/dev/null' \
    || { log "conexao PostgreSQL falhou"; return 1; }
  return 0
}

# (14) rollback determinístico se qualquer teste falhar
if ! health_ok; then
  log "HEALTH FALHOU — revertendo para ${PREV:-nenhum}"
  if [ -n "$PREV" ] && [ -d "$PREV" ]; then
    ln -sfn "$PREV" "$SRV/.current.new"; mv -Tf "$SRV/.current.new" "$CURRENT"
    systemctl restart "$API_UNIT" "$WORKER_UNIT"
    [ "$ENABLE_TELEGRAM" -eq 1 ] && systemctl restart "$TELEGRAM_UNIT" || true
    health_ok && log "rollback OK" || log "ATENCAO: rollback tambem falhou — intervencao manual"
  else
    log "sem release anterior para rollback (primeiro deploy)"
  fi
  die "deploy falhou; estado revertido"
fi

# (15) retenção: mantém os KEEP releases mais novos, remove só o excedente
mapfile -t OLD < <(ls -1dt "$RELEASES"/*/ 2>/dev/null | tail -n +$((KEEP+1)))
for d in "${OLD[@]:-}"; do [ -n "$d" ] && [ "$(readlink -f "$d")" != "$(readlink -f "$CURRENT")" ] && { log "removendo release antigo $(basename "$d")"; rm -rf "$d"; }; done

log "DEPLOY OK  sha=${SHA:0:12}  release=$(basename "$REL")"
