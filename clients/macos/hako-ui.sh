#!/usr/bin/env bash
set -Eeuo pipefail

if ! ssh hako-vps "ss -ltn | grep -q '127.0.0.1:9119 '"; then
  echo "SSH funciona, mas o painel Hermes não está ouvindo em 127.0.0.1:9119 na VPS." >&2
  exit 1
fi

echo "Mantenha esta janela aberta e acesse http://127.0.0.1:9119/"
exec ssh -N \
  -o ExitOnForwardFailure=yes \
  -L 9119:127.0.0.1:9119 \
  hako-vps
