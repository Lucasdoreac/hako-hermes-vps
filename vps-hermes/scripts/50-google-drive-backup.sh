#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { echo "Execute como root." >&2; exit 1; }
[[ -t 0 ]] || { echo "A primeira configuração exige terminal interativo." >&2; exit 1; }

install -d -o root -g root -m 0700 /root/.config/rclone /root/.config/restic /etc/hako

if ! rclone listremotes | grep -qx 'gdrive:'; then
  echo "Crie agora um remote Google Drive chamado exatamente 'gdrive'."
  echo "Use acesso limitado a uma pasta quando o fluxo oferecer essa opção."
  rclone config
fi
rclone listremotes | grep -qx 'gdrive:' || { echo "Remote gdrive: não configurado." >&2; exit 1; }
chmod 0600 /root/.config/rclone/rclone.conf

password_file=/root/.config/restic/hako-vps-password
if [[ ! -s $password_file ]]; then
  read -rsp 'Senha nova para criptografar o backup Restic: ' p1; echo
  read -rsp 'Repita a senha: ' p2; echo
  [[ $p1 == "$p2" && ${#p1} -ge 20 ]] || {
    echo "As senhas diferem ou têm menos de 20 caracteres." >&2; exit 1;
  }
  printf '%s' "$p1" > "$password_file"
  unset p1 p2
  chmod 0600 "$password_file"
fi

cat > /etc/hako/restic.env <<EOF
RESTIC_REPOSITORY=rclone:gdrive:hako-vps-restic
RESTIC_PASSWORD_FILE=$password_file
RCLONE_CONFIG=/root/.config/rclone/rclone.conf
RCLONE_TPSLIMIT=4
RCLONE_TPSLIMIT_BURST=4
EOF
chmod 0600 /etc/hako/restic.env

cat > /usr/local/sbin/hako-restic-backup <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
set -a
. /etc/hako/restic.env
set +a
restic backup /home/hermes/.hermes /srv/hermes-work /etc /var/lib/hako \
  --exclude='/home/hermes/.hermes/cache' \
  --exclude='/home/hermes/.hermes/hermes-agent/.git'
restic forget --keep-daily 7 --keep-weekly 5 --keep-monthly 12 --prune
restic check
EOF
chown root:root /usr/local/sbin/hako-restic-backup
chmod 0750 /usr/local/sbin/hako-restic-backup

cat > /etc/systemd/system/hako-restic-backup.service <<'EOF'
[Unit]
Description=Backup externo criptografado da VPS para Google Drive
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
EnvironmentFile=/etc/hako/restic.env
Environment=HOME=/root
Environment=XDG_CACHE_HOME=/var/cache/hako-restic
CacheDirectory=hako-restic
ExecStart=/usr/local/sbin/hako-restic-backup
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/var/cache/hako-restic
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictSUIDSGID=yes
LockPersonality=yes
EOF
cat > /etc/systemd/system/hako-restic-backup.timer <<'EOF'
[Unit]
Description=Backup externo diário da VPS
[Timer]
OnCalendar=*-*-* 04:10:00 UTC
RandomizedDelaySec=20m
Persistent=true
[Install]
WantedBy=timers.target
EOF

set -a
. /etc/hako/restic.env
set +a
restic snapshots >/dev/null 2>&1 || restic init
/usr/local/sbin/hako-restic-backup
systemctl daemon-reload
systemctl enable --now hako-restic-backup.timer
restic snapshots

echo "Backup criado e verificado. Guarde a senha Restic fora desta VPS; sem ela a restauração é impossível."
