#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
local_script="$repo_root/vps-hermes/scripts/95-security-audit.sh"
remote_script=.local/share/hako/hako-vps-security-audit.sh

ssh hako-vps 'mkdir -p ~/.local/share/hako && chmod 700 ~/.local/share/hako'
scp "$local_script" "hako-vps:$remote_script"
echo "Digite sua senha sudo da VPS quando solicitado."
ssh -t hako-vps 'sudo bash "$HOME/.local/share/hako/hako-vps-security-audit.sh"'
