#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { echo "Execute como root." >&2; exit 1; }

apt-get install -y --no-install-recommends \
  build-essential ffmpeg libffi-dev python3-dev ripgrep \
  "linux-modules-extra-$(uname -r)"
systemctl enable --now zramswap 2>/dev/null || \
  echo "Aviso: zram não pôde ser iniciado neste kernel."

id hermes >/dev/null 2>&1 || adduser --disabled-password --gecos '' --shell /bin/bash hermes
passwd -l hermes >/dev/null
install -d -m 0750 -o hermes -g hermes /srv/hermes-work
install -d -m 0700 -o hermes -g hermes /home/hermes/.hermes

tmp_installer=$(mktemp)
trap 'rm -f "$tmp_installer"' EXIT
curl --proto '=https' --tlsv1.2 -fsSL https://hermes-agent.nousresearch.com/install.sh -o "$tmp_installer"
echo "Installer oficial SHA-256: $(sha256sum "$tmp_installer" | cut -d' ' -f1)"
chmod 0755 "$tmp_installer"
sudo -u hermes -H bash "$tmp_installer" --skip-setup

hermes_bin=/home/hermes/.hermes/hermes-agent/venv/bin/hermes
[[ -x $hermes_bin ]] || { echo "Binário Hermes não encontrado após instalação." >&2; exit 1; }
ln -sfn "$hermes_bin" /usr/local/bin/hermes

# O instalador baixa o Chromium no perfil não privilegiado. As bibliotecas do
# sistema são instaladas separadamente como root, conforme a documentação oficial.
if [[ -x /home/hermes/.hermes/node/bin/npx ]]; then
  PATH="/home/hermes/.hermes/node/bin:$PATH" HOME=/home/hermes \
    /home/hermes/.hermes/node/bin/npx --yes playwright install-deps chromium
  ln -sfn /home/hermes/.hermes/node/bin/node /usr/local/bin/node
  ln -sfn /home/hermes/.hermes/node/bin/npm /usr/local/bin/npm
  ln -sfn /home/hermes/.hermes/node/bin/npx /usr/local/bin/npx
else
  echo "Aviso: npx gerenciado não encontrado; execute depois: sudo npx playwright install-deps chromium"
fi

cat > /home/hermes/.hermes/config.yaml <<'EOF'
approvals:
  mode: manual
  timeout: 120
  cron_mode: deny
  mcp_reload_confirm: true
  destructive_slash_confirm: true
terminal:
  backend: local
  cwd: /srv/hermes-work
gateway:
  systemd_watchdog_seconds: 120
updates:
  pre_update_backup: quick
EOF

cat > /home/hermes/.hermes/.env <<'EOF'
HERMES_YOLO_MODE=0
HERMES_EXEC_ASK=1
HERMES_WRITE_SAFE_ROOT=/srv/hermes-work:/home/hermes/.hermes
API_SERVER_HOST=127.0.0.1
API_SERVER_PORT=8642
GATEWAY_ALLOW_ALL_USERS=false
EOF
chown -R hermes:hermes /home/hermes/.hermes /srv/hermes-work
chmod 0700 /home/hermes/.hermes
chmod 0600 /home/hermes/.hermes/.env /home/hermes/.hermes/config.yaml

cat > /usr/local/sbin/hermes-backup <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
dest=/var/backups/hermes
install -d -m 0700 "$dest"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
tar --create --gzip --file "$dest/hermes-$stamp.tar.gz" \
  --exclude='.hermes/cache' --exclude='.hermes/hermes-agent/.git' \
  -C /home/hermes .hermes -C /srv hermes-work
chmod 0600 "$dest/hermes-$stamp.tar.gz"
find "$dest" -type f -name 'hermes-*.tar.gz' -mtime +7 -delete
EOF
chmod 0750 /usr/local/sbin/hermes-backup

cat > /etc/systemd/system/hermes-backup.service <<'EOF'
[Unit]
Description=Backup local do Hermes Agent
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/hermes-backup
EOF
cat > /etc/systemd/system/hermes-backup.timer <<'EOF'
[Unit]
Description=Backup diário do Hermes Agent
[Timer]
OnCalendar=*-*-* 03:20:00 UTC
RandomizedDelaySec=15m
Persistent=true
[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now hermes-backup.timer

sudo -u hermes -H "$hermes_bin" version
echo "Hermes instalado. Execute 'sudo -iu hermes' e depois 'hermes setup --portal' ou 'hermes model'."
