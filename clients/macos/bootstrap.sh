#!/usr/bin/env bash
set -Eeuo pipefail

install=false
[[ ${1:-} == --install ]] && install=true
[[ $(uname -s) == Darwin ]] || { echo "Este script exige macOS." >&2; exit 1; }

missing=()
for command_name in git gh jq ssh ssh-keygen; do
  command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
done

if ((${#missing[@]} == 0)); then
  echo "Ferramentas básicas presentes."
elif ! $install; then
  printf 'Ferramentas ausentes: %s\n' "${missing[*]}"
  echo "Revise o script e execute novamente com --install, se desejar."
  exit 2
else
  command -v brew >/dev/null 2>&1 || {
    echo "Homebrew não encontrado. Instale-o pelo site oficial e repita." >&2
    echo "https://brew.sh/" >&2
    exit 3
  }
  brew install git gh jq
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

git --version
gh --version | head -n 1
ssh -V

if gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI autenticado."
else
  echo "GitHub CLI ainda não autenticado. Execute: gh auth login"
fi

if [[ -f $HOME/.ssh/hako_contabo_ed25519 ]]; then
  mode=$(stat -f '%Lp' "$HOME/.ssh/hako_contabo_ed25519")
  [[ $mode == 600 ]] || {
    echo "Corrigindo permissão da chave HAKO para 600."
    chmod 600 "$HOME/.ssh/hako_contabo_ed25519"
  }
else
  echo "Chave do Mac ainda não criada; siga clients/macos/README.md."
fi

echo "Verificação macOS concluída."
