#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { echo "Execute como root." >&2; exit 1; }
[[ -r /etc/os-release ]] || { echo "Sistema não identificado." >&2; exit 1; }
. /etc/os-release
[[ ${ID:-} == ubuntu ]] || { echo "Esperado Ubuntu; encontrado ${ID:-desconhecido}." >&2; exit 1; }

echo "OS: ${PRETTY_NAME}"
echo "Kernel: $(uname -r)"
echo "CPU: $(nproc) vCPU"
free -h
df -h /
ip -brief address
ss -lntup
timedatectl status --no-pager

getent hosts github.com >/dev/null
curl --proto '=https' --tlsv1.2 -fsSI https://hermes-agent.nousresearch.com/install.sh >/dev/null
echo "Preflight concluído. Nenhuma alteração foi feita."
