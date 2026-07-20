#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: sudo install-hako-runtime.sh SOURCE_DIR [--migrate] [--start] [--enable-telegram]

Default behavior prepares a versioned release, venv, users, directories, env
skeletons and systemd units. It does not migrate or start services unless flags
are explicit.
EOF
}

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'execute como root'; exit 2; }
[[ $# -ge 1 ]] || { usage; exit 2; }

source_dir="$(realpath "$1")"
shift
migrate=0
start=0
enable_telegram=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --migrate) migrate=1 ;;
    --start) start=1 ;;
    --enable-telegram) enable_telegram=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "flag desconhecida: $1"; usage; exit 2 ;;
  esac
  shift
done

for required in app/server.py tools/runtime_worker.py tools/telegram_receiver.py requirements.txt db/schema.sql; do
  [[ -f "$source_dir/$required" ]] || { echo "release inválido: falta $required"; exit 2; }
done

command -v rsync >/dev/null || { echo 'rsync ausente'; exit 2; }
command -v python3 >/dev/null || { echo 'python3 ausente'; exit 2; }
command -v systemctl >/dev/null || { echo 'systemd ausente'; exit 2; }

if ! id hako-creative >/dev/null 2>&1; then
  useradd --system --home-dir /srv/hako-creative --create-home --shell /usr/sbin/nologin hako-creative
fi

install -d -o root -g hako-creative -m 0750 /etc/hako-creative
install -d -o root -g hako-creative -m 0750 /srv/hako-creative/releases
install -d -o hako-creative -g hako-creative -m 0750 \
  /srv/hako-creative/assets /srv/hako-creative/cache /srv/hako-creative/logs

commit="$(git -C "$source_dir" rev-parse --short=12 HEAD 2>/dev/null || printf 'nogit')"
release_name="$(date -u +%Y%m%dT%H%M%SZ)-$commit"
release_dir="/srv/hako-creative/releases/$release_name"
install -d -o root -g hako-creative -m 0750 "$release_dir"
rsync -a --delete --exclude '.git/' --exclude '.venv/' "$source_dir/" "$release_dir/"
chown -R root:hako-creative "$release_dir"
find "$release_dir" -type d -exec chmod 0750 {} +
find "$release_dir" -type f -exec chmod 0640 {} +
chmod 0750 "$release_dir"/tools/*.py 2>/dev/null || true

python3 -m venv "$release_dir/.venv"
"$release_dir/.venv/bin/pip" install --disable-pip-version-check --no-cache-dir -r "$release_dir/requirements.txt"
chown -R root:hako-creative "$release_dir/.venv"
chmod -R g+rX,o-rwx "$release_dir/.venv"

ln -sfn "$release_dir" /srv/hako-creative/current
chown -h root:hako-creative /srv/hako-creative/current

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(realpath "$script_dir/../..")"
if [[ ! -f /etc/hako-creative/runtime.env ]]; then
  install -o root -g hako-creative -m 0640 \
    "$repo_root/vps-hermes/env/hako-creative-runtime.env.example" \
    /etc/hako-creative/runtime.env
fi
if [[ ! -f /etc/hako-creative/telegram.env ]]; then
  install -o root -g hako-creative -m 0640 \
    "$repo_root/vps-hermes/env/hako-telegram.env.example" \
    /etc/hako-creative/telegram.env
fi

for unit in hako-creative-api.service hako-creative-worker.service hako-telegram-receiver.service; do
  install -o root -g root -m 0644 "$repo_root/vps-hermes/systemd/$unit" "/etc/systemd/system/$unit"
done
systemd-analyze verify \
  /etc/systemd/system/hako-creative-api.service \
  /etc/systemd/system/hako-creative-worker.service \
  /etc/systemd/system/hako-telegram-receiver.service
systemctl daemon-reload

contains_placeholder() { grep -q 'REPLACE_' "$1"; }
if (( migrate || start )); then
  contains_placeholder /etc/hako-creative/runtime.env && {
    echo 'runtime.env contém placeholders; migração/start bloqueados'; exit 1;
  }
fi

if (( migrate )); then
  set -a
  # shellcheck disable=SC1091
  source /etc/hako-creative/runtime.env
  set +a
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$release_dir/db/schema.sql"
  for migration in "$release_dir"/db/migrations/*.sql; do
    [[ -e "$migration" ]] || continue
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$migration"
  done
fi

systemctl enable hako-creative-api.service hako-creative-worker.service
if (( enable_telegram )); then
  contains_placeholder /etc/hako-creative/telegram.env && {
    echo 'telegram.env contém placeholders; receiver não será habilitado'; exit 1;
  }
  systemctl enable hako-telegram-receiver.service
fi

if (( start )); then
  systemctl restart hako-creative-api.service hako-creative-worker.service
  if (( enable_telegram )); then
    systemctl restart hako-telegram-receiver.service
  fi
fi

printf 'release preparado: %s\n' "$release_dir"
printf 'current -> %s\n' "$(readlink -f /srv/hako-creative/current)"
if (( start == 0 )); then
  echo 'serviços não iniciados; revise envs, rode preflight e use --start explicitamente'
fi
