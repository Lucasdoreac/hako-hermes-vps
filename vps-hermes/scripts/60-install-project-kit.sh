#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { echo "Execute como root." >&2; exit 1; }
id hermes >/dev/null 2>&1 || { echo "Usuário hermes ausente." >&2; exit 1; }

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_dir=$repo_root/assets/hermes-skills/hako-project-kit
target=/home/hermes/.hermes/skills/hako-project-kit
[[ -f $source_dir/SKILL.md ]] || { echo "Skill ausente: $source_dir" >&2; exit 1; }

backup=
if [[ -e $target ]]; then
  backup=/home/lucas/hako-project-kit-backup-$(date -u +%Y%m%dT%H%M%SZ)
  cp -a -- "$target" "$backup"
  chown -R lucas:lucas "$backup"
fi

install -d -m 0700 -o hermes -g hermes /home/hermes/.hermes/skills
stage=$(mktemp -d /home/hermes/.hermes/skills/.hako-project-kit.XXXXXX)
trap 'rm -rf -- "$stage"' EXIT
cp -a -- "$source_dir/." "$stage/"
chown -R hermes:hermes "$stage"
find "$stage" -type d -exec chmod 0700 {} +
find "$stage" -type f -exec chmod 0600 {} +
find "$stage/scripts" -type f -exec chmod 0700 {} +
rm -rf -- "$target"
mv -- "$stage" "$target"
trap - EXIT

echo "Installed: $target"
[[ -z $backup ]] || echo "Backup: $backup"
echo "No system packages, runtimes, Docker, MCPs or credentials were installed."

