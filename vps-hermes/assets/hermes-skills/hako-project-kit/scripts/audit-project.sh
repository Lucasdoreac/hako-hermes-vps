#!/usr/bin/env bash
set -Eeuo pipefail

root=${1:-.}
root=$(cd "$root" && pwd)
printf 'project=%s\n' "$root"
printf 'git=%s\n' "$(git -C "$root" rev-parse --is-inside-work-tree 2>/dev/null || echo false)"

for item in AGENTS.md .hermes.md pyproject.toml uv.lock package.json pnpm-lock.yaml package-lock.json \
  go.mod Cargo.toml compose.yaml Dockerfile mise.toml .tool-versions; do
  [[ -e $root/$item ]] && printf 'found=%s\n' "$item"
done

for cli in git rg jq python3 uv node corepack gh docker; do
  if command -v "$cli" >/dev/null 2>&1; then
    printf 'cli=%s:present\n' "$cli"
  else
    printf 'cli=%s:missing\n' "$cli"
  fi
done

echo 'This audit is read-only. Missing does not mean authorized to install.'
