#!/usr/bin/env bash
#
# Migra o n8n da unit `systemd --user` do humano `lucas` para um usuario tecnico
# dedicado (`hako-n8n`, nologin) com unit de SISTEMA, fechando o ADR-008 na
# pratica (ver vps-hermes/docs/N8N-SERVICE.md e o ADR-016 do repo de produto).
#
# O risco central: o `N8N_ENCRYPTION_KEY` vive em ~/.n8n/config. Se ele nao
# migrar junto com ~/.n8n, TODAS as credenciais do cofre viram lixo cifrado.
# Este script copia o diretorio .n8n inteiro (a chave junto) e ABORTA se a chave
# no destino nao bater com a origem.
#
# Modos:
#   (sem flag)   --check : so valida pre-condicoes e imprime o plano. Nao muda nada.
#   --cutover           : executa a migracao (para o n8n antigo, copia, verifica,
#                         instala a unit de sistema, habilita e inicia o novo).
#
# Nao roda sozinho em deploy: exige --cutover explicito, numa janela de manutencao,
# com backup preservado e, depois, um reboot controlado para provar o boot.
#
set -euo pipefail

SOURCE_USER="${SOURCE_USER:-lucas}"
NEW_USER="${NEW_USER:-hako-n8n}"
NEW_HOME="${NEW_HOME:-/srv/hako-n8n}"
BACKUP_DIR="${BACKUP_DIR:-/srv/hako-n8n-backups}"
UNIT_NAME="hako-n8n.service"

log()  { printf '[migrate-n8n] %s\n' "$*"; }
die()  { printf '[migrate-n8n] ERRO: %s\n' "$*" >&2; exit 1; }

mode="check"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)   mode="check" ;;
    --cutover) mode="cutover" ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "flag desconhecida: $1 (use --check ou --cutover)" ;;
  esac
  shift
done

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "execute como root"
command -v rsync >/dev/null      || die "rsync ausente"
command -v systemctl >/dev/null  || die "systemd ausente"
command -v sha256sum >/dev/null  || die "sha256sum ausente"

src_home="$(getent passwd "$SOURCE_USER" | cut -d: -f6)"
[[ -n "$src_home" ]] || die "usuario de origem '$SOURCE_USER' nao existe"
src_n8n="$src_home/.n8n"
src_node="$src_home/.local/node"
src_config="$src_n8n/config"

[[ -d "$src_n8n" ]]     || die "nao encontrei $src_n8n"
[[ -f "$src_config" ]]  || die "nao encontrei $src_config (onde vive a N8N_ENCRYPTION_KEY)"

# Impressao digital da chave na origem: sha256 do valor de encryptionKey.
# Nunca imprime a chave em si.
key_fingerprint() {
  # aceita "encryptionKey":"..." (JSON) ou N8N_ENCRYPTION_KEY=... (env)
  local f="$1" val
  val="$(grep -oE '"encryptionKey"[[:space:]]*:[[:space:]]*"[^"]+"' "$f" 2>/dev/null | sed -E 's/.*"encryptionKey"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' | head -1)"
  [[ -n "$val" ]] || val="$(grep -oE 'N8N_ENCRYPTION_KEY[[:space:]]*=[[:space:]]*\S+' "$f" 2>/dev/null | sed -E 's/.*=[[:space:]]*//' | head -1)"
  [[ -n "$val" ]] || return 1
  printf '%s' "$val" | sha256sum | cut -d' ' -f1
}

src_fp="$(key_fingerprint "$src_config")" || die "nao achei a encryptionKey em $src_config; aborta antes de arriscar o cofre"
log "origem : $SOURCE_USER ($src_n8n)"
log "destino: $NEW_USER ($NEW_HOME/.n8n)"
log "chave de cifra presente na origem (fingerprint ${src_fp:0:12}...); nunca sera impressa por extenso"
[[ -d "$src_node" ]] && log "node do n8n: $src_node (sera copiado)" || log "AVISO: $src_node ausente; ajuste PATH/ExecStart ou instale o node no novo home"

if [[ "$mode" == "check" ]]; then
  cat <<EOF

[PLANO] (--check: nada foi alterado)
  1. para o n8n antigo:            su - $SOURCE_USER -c 'systemctl --user stop n8n'
  2. backup .n8n (com a chave):    $BACKUP_DIR/n8n-<timestamp>.tgz
  3. cria usuario de sistema:      useradd --system --home-dir $NEW_HOME --shell /usr/sbin/nologin $NEW_USER
  4. copia node e .n8n para:       $NEW_HOME (chave junto)
  5. VERIFICA a chave no destino == origem (aborta se divergir)
  6. instala/habilita a unit:      /etc/systemd/system/$UNIT_NAME
  7. desabilita a unit de usuario antiga e inicia a de sistema
  8. (voce) reboot controlado para provar sobrevivencia ao boot

Rode com --cutover, numa janela de manutencao, para executar.
EOF
  exit 0
fi

# ---------------------------------------------------------------------------
# --cutover: a partir daqui, muda a maquina.
# ---------------------------------------------------------------------------
install -d -o root -g root -m 0700 "$BACKUP_DIR"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
backup="$BACKUP_DIR/n8n-$ts.tgz"

rollback() {
  log "ROLLBACK: religando o n8n antigo do usuario $SOURCE_USER"
  su - "$SOURCE_USER" -c 'systemctl --user start n8n' 2>/dev/null || true
  log "backup preservado em: $backup"
  log "o novo servico NAO foi iniciado; nenhuma porta em conflito"
}
trap 'rollback' ERR

log "parando o n8n antigo (unit de usuario de $SOURCE_USER) para copia consistente"
su - "$SOURCE_USER" -c 'systemctl --user stop n8n' 2>/dev/null || log "aviso: nao consegui parar via --user (talvez ja parado); seguindo"

log "backup de $src_n8n -> $backup"
tar -czf "$backup" -C "$src_home" .n8n
chmod 0600 "$backup"
tar -tzf "$backup" | grep -q '\.n8n/config$' || die "backup nao contem .n8n/config; aborta"

if ! id "$NEW_USER" >/dev/null 2>&1; then
  log "criando usuario de sistema $NEW_USER (nologin)"
  useradd --system --home-dir "$NEW_HOME" --create-home --shell /usr/sbin/nologin "$NEW_USER"
fi
install -d -o "$NEW_USER" -g "$NEW_USER" -m 0755 "$NEW_HOME/.local"

if [[ -d "$src_node" ]]; then
  log "copiando node do n8n"
  rsync -a --delete "$src_node/" "$NEW_HOME/.local/node/"
  chown -R "$NEW_USER":"$NEW_USER" "$NEW_HOME/.local"
fi

log "copiando dados do n8n (SQLite + config com a chave)"
rsync -a "$src_n8n/" "$NEW_HOME/.n8n/"
chown -R "$NEW_USER":"$NEW_USER" "$NEW_HOME/.n8n"
chmod 0700 "$NEW_HOME/.n8n"
chmod 0600 "$NEW_HOME/.n8n/config" 2>/dev/null || true
find "$NEW_HOME/.n8n" -maxdepth 1 -name '*.sqlite' -exec chmod 0600 {} + 2>/dev/null || true

log "verificando que a chave de cifra migrou intacta"
dst_fp="$(key_fingerprint "$NEW_HOME/.n8n/config")" || die "chave ausente no destino; o cofre nao decifraria. Rollback."
[[ "$dst_fp" == "$src_fp" ]] || die "chave do destino difere da origem (${dst_fp:0:12}... != ${src_fp:0:12}...). Rollback."
log "chave OK: destino confere com a origem"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
unit_src="$script_dir/../systemd/$UNIT_NAME"
[[ -f "$unit_src" ]] || die "unit versionada ausente: $unit_src"
log "instalando unit de sistema $UNIT_NAME"
install -o root -g root -m 0644 "$unit_src" "/etc/systemd/system/$UNIT_NAME"
systemd-analyze verify "/etc/systemd/system/$UNIT_NAME" || die "systemd-analyze reprovou a unit"
systemctl daemon-reload

log "desabilitando a unit de usuario antiga (evita disputa pela porta 5678 no boot)"
su - "$SOURCE_USER" -c 'systemctl --user disable n8n' 2>/dev/null || log "aviso: nao consegui desabilitar a unit de usuario; faca a mao"

log "habilitando e iniciando $UNIT_NAME"
systemctl enable "$UNIT_NAME"
systemctl start "$UNIT_NAME"

trap - ERR
sleep 3
if systemctl is-active --quiet "$UNIT_NAME"; then
  log "OK: $UNIT_NAME ativo sob $NEW_USER"
else
  die "servico nao ficou ativo; investigue com: journalctl -u $UNIT_NAME -n 50 (backup em $backup)"
fi

cat <<EOF

[FEITO] n8n migrado para o usuario de sistema $NEW_USER.
  - backup: $backup
  - confira: systemctl status $UNIT_NAME ; ss -ltnp | grep 5678
  - cgroup deve apontar para $UNIT_NAME, nao mais para user@ de $SOURCE_USER
  - PROXIMO: reboot controlado para provar a sobrevivencia ao boot (ver N8N-SERVICE.md)
  - remova o workflow orfao da instancia (runbook em N8N-SERVICE.md)
EOF
