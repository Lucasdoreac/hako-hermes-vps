#!/usr/bin/env bash
# Provisiona as dependências de sistema do renderer de protótipos do HAKO
# Creative: Node.js (NodeSource) e FFmpeg (Ubuntu).
#
# Por que existe: `deploy-hako-runtime.sh` (repo de produto) exige `node`, `npm`,
# `ffmpeg` e `ffprobe` no PATH e FALHA FECHADO antes de trocar o symlink
# `current` se faltarem. Ele instala as dependências npm do renderer e o browser
# do HyperFrames, mas não instala pacotes de sistema — isso é provisionamento, e
# provisionamento mora aqui. Até 22/07/2026 nada neste repositório instalava
# essas dependências: `hako-creative-preflight.sh` apenas CONFERIA se existiam.
#
# O que este script NÃO faz, de propósito:
#   - não instala o browser do HyperFrames (o deploy do produto faz, via
#     `hyperframes browser ensure`, no cache do serviço);
#   - não toca no Node de `~lucas/.local/node`, que é o do n8n e é independente
#     deste (ver docs/N8N-SERVICE.md);
#   - não reinicia nenhum serviço.
set -euo pipefail

NODE_MAJOR="${NODE_MAJOR:-24}"
KEYRING=/usr/share/keyrings/nodesource.gpg
SOURCES=/etc/apt/sources.list.d/nodesource.sources

usage() {
  cat <<'EOF'
Uso: sudo 70-install-renderer-deps.sh [--check]

  (sem flag)  instala Node.js (NodeSource) e FFmpeg
  --check     só relata o estado atual; não altera nada (não exige root)

Variável: NODE_MAJOR (padrão 24) escolhe a linha do NodeSource.
EOF
}

check_only=0
case "${1:-}" in
  --check) check_only=1 ;;
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) echo "flag desconhecida: $1" >&2; usage; exit 2 ;;
esac

report() {
  echo "== estado das dependências do renderer =="
  for bin in node npm ffmpeg ffprobe; do
    if command -v "$bin" >/dev/null 2>&1; then
      printf '%-10s %-28s %s\n' "$bin" "$(command -v "$bin")" \
        "$("$bin" --version 2>&1 | head -n 1)"
    else
      printf '%-10s %s\n' "$bin" 'AUSENTE — o deploy do produto falhará fechado'
    fi
  done
  if command -v dpkg >/dev/null 2>&1; then
    printf '%-10s %s\n' 'pacote' "$(dpkg -l nodejs 2>/dev/null | awk '/^ii/{print $2" "$3}')"
  fi
}

if (( check_only )); then
  report
  exit 0
fi

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'execute como root' >&2; exit 2; }
command -v apt-get >/dev/null || { echo 'apt-get ausente; distro não suportada' >&2; exit 2; }

# 1. Repositório do NodeSource. A chave é baixada e convertida uma vez; o
#    `Signed-By` amarra o repo a ela, então um mirror trocado não passa.
if [[ ! -f "$KEYRING" ]]; then
  echo "==> importando chave do NodeSource"
  install -d -m 0755 /usr/share/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o "$KEYRING"
  chmod 0644 "$KEYRING"
fi

if [[ ! -f "$SOURCES" ]]; then
  echo "==> registrando repositório node_${NODE_MAJOR}.x"
  cat >"$SOURCES" <<EOF
Types: deb
URIs: https://deb.nodesource.com/node_${NODE_MAJOR}.x
Suites: nodistro
Components: main
Architectures: amd64
Signed-By: ${KEYRING}
EOF
  chmod 0644 "$SOURCES"
fi

# 2. Pacotes. `nodejs` do NodeSource já traz o npm; não instale `npm` do Ubuntu
#    junto, os dois conflitam.
echo "==> instalando nodejs e ffmpeg"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nodejs ffmpeg

# 3. Verificação: os quatro binários que o deploy do produto exige.
faltando=0
for bin in node npm ffmpeg ffprobe; do
  command -v "$bin" >/dev/null 2>&1 || { echo "FALTA: $bin" >&2; faltando=1; }
done
(( faltando == 0 )) || { echo 'provisionamento incompleto' >&2; exit 1; }

report
echo '==> ok. O browser do HyperFrames é instalado pelo deploy do produto.'
