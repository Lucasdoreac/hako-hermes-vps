#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { echo "Execute com sudo." >&2; exit 1; }
: "${SUDO_USER:?Execute via sudo a partir da conta administrativa.}"
[[ $SUDO_USER != root ]] || { echo "Execute via sudo, não em uma sessão root." >&2; exit 1; }

admin_user=$SUDO_USER
admin_keys=$(getent passwd "$admin_user" | cut -d: -f6)/.ssh/authorized_keys
[[ -s $admin_keys ]] || { echo "Chave do administrador ausente; abortando." >&2; exit 1; }
id -nG "$admin_user" | grep -qw sudo || { echo "Administrador sem grupo sudo; abortando." >&2; exit 1; }

stamp=$(date -u +%Y%m%dT%H%M%SZ)
rollback=/var/backups/hako-remediation/$stamp
install -d -m 0700 "$rollback"
cp -a /etc/ssh/sshd_config /etc/ssh/sshd_config.d "$rollback/"
cp -a /etc/sudoers /etc/sudoers.d "$rollback/"
cp -a /usr/local/sbin/hermes-backup "$rollback/"

cat > /etc/ssh/sshd_config.d/00-hako-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding local
PermitTunnel no
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
chmod 0644 /etc/ssh/sshd_config.d/00-hako-hardening.conf
rm -f /etc/ssh/sshd_config.d/90-hako-hardening.conf

/usr/sbin/sshd -t
effective=$(/usr/sbin/sshd -T)
grep -qx 'permitrootlogin no' <<<"$effective"
grep -qx 'passwordauthentication no' <<<"$effective"
grep -qx 'authenticationmethods publickey' <<<"$effective"

# A conta de imagem está bloqueada e não possui chave válida. Removemos também
# sudo e qualquer regra NOPASSWD nominal, preservando os arquivos no rollback.
if id ubuntu >/dev/null 2>&1; then
  passwd -S ubuntu | grep -q '^ubuntu L ' || {
    echo "Conta ubuntu não está bloqueada; abortando para revisão manual." >&2
    exit 1
  }
  usermod -L -s /usr/sbin/nologin ubuntu
  gpasswd -d ubuntu sudo >/dev/null 2>&1 || true
  while IFS= read -r sudo_file; do
    tmp=$(mktemp)
    sed -E '/^[[:space:]]*ubuntu[[:space:]].*NOPASSWD/ s/^/# disabled by HAKO security remediation: /' \
      "$sudo_file" > "$tmp"
    install -o root -g root -m 0440 "$tmp" "$sudo_file"
    rm -f "$tmp"
  done < <(grep -RIlE '^[[:space:]]*ubuntu[[:space:]].*NOPASSWD' /etc/sudoers /etc/sudoers.d 2>/dev/null || true)
  visudo -cf /etc/sudoers
fi

cat > /usr/local/sbin/hermes-backup <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
dest=/var/backups/hermes
install -d -m 0700 "$dest"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
archive="$dest/hermes-$stamp.tar.gz"
tar --create --gzip --file "$archive" \
  --ignore-failed-read --warning=no-file-changed \
  --exclude='.hermes/cache' --exclude='.hermes/hermes-agent/.git' \
  -C /home/hermes .hermes -C /srv hermes-work
gzip -t "$archive"
chmod 0600 "$archive"
find "$dest" -type f -name 'hermes-*.tar.gz' -mtime +7 -delete
EOF
chown root:root /usr/local/sbin/hermes-backup
chmod 0750 /usr/local/sbin/hermes-backup

install -d -o root -g root -m 0750 /var/cache/hako-restic
install -d -o root -g root -m 0755 /etc/systemd/system/hako-restic-backup.service.d
cat > /etc/systemd/system/hako-restic-backup.service.d/10-hardening.conf <<'EOF'
[Service]
Environment=HOME=/root
Environment=XDG_CACHE_HOME=/var/cache/hako-restic
CacheDirectory=hako-restic
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

systemctl daemon-reload
systemctl reload ssh
systemctl reset-failed hermes-backup.service
systemctl start hermes-backup.service
systemctl is-active --quiet hermes-backup.timer

echo "Remediação aplicada. Rollback: $rollback"
echo "SSH efetivo:"
/usr/sbin/sshd -T | grep -E '^(permitrootlogin|passwordauthentication|authenticationmethods) '
echo "Conta ubuntu:"
passwd -S ubuntu || true
getent group sudo
sudo -l -U ubuntu 2>/dev/null || true
systemctl status hermes-backup.service --no-pager
