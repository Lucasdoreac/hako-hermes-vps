#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { echo "Execute como root." >&2; exit 1; }
: "${ADMIN_USER:?Defina ADMIN_USER}"
: "${ADMIN_SSH_PUBLIC_KEY:?Defina ADMIN_SSH_PUBLIC_KEY com uma chave pública SSH}"
[[ $ADMIN_USER =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || { echo "ADMIN_USER inválido." >&2; exit 1; }
[[ $ADMIN_SSH_PUBLIC_KEY == ssh-ed25519\ * || $ADMIN_SSH_PUBLIC_KEY == ssh-rsa\ * || $ADMIN_SSH_PUBLIC_KEY == ecdsa-sha2-nistp256\ * ]] || {
  echo "Formato de chave pública não reconhecido." >&2; exit 1;
}

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y dist-upgrade
apt-get install -y --no-install-recommends \
  ca-certificates curl git xz-utils jq rsync ufw fail2ban unattended-upgrades \
  apt-listchanges chrony auditd audispd-plugins aide logrotate
# zram é uma melhoria opcional e não deve interromper o bootstrap se o pacote
# não estiver disponível nos repositórios habilitados da imagem.
apt-get install -y --no-install-recommends zram-tools || echo "Aviso: zram-tools indisponível; seguindo sem zram."

id "$ADMIN_USER" >/dev/null 2>&1 || adduser --disabled-password --gecos '' "$ADMIN_USER"
usermod -aG sudo "$ADMIN_USER"

# Não bloqueie o SSH de root deixando um administrador incapaz de elevar
# privilégios. Para contas novas, defina a senha fora do repositório.
password_state=$(passwd -S "$ADMIN_USER" | awk '{print $2}')
if [[ $password_state != P ]]; then
  if [[ -t 0 ]]; then
    echo "Defina agora a senha sudo de $ADMIN_USER (não será armazenada nos scripts)."
    passwd "$ADMIN_USER"
  else
    echo "$ADMIN_USER não possui senha válida e não há terminal interativo; abortando." >&2
    exit 1
  fi
fi
install -d -m 0700 -o "$ADMIN_USER" -g "$ADMIN_USER" "/home/$ADMIN_USER/.ssh"
printf '%s\n' "$ADMIN_SSH_PUBLIC_KEY" > "/home/$ADMIN_USER/.ssh/authorized_keys"
chown "$ADMIN_USER:$ADMIN_USER" "/home/$ADMIN_USER/.ssh/authorized_keys"
chmod 0600 "/home/$ADMIN_USER/.ssh/authorized_keys"

cat > /etc/apt/apt.conf.d/52hako-unattended-upgrades <<'EOF'
Unattended-Upgrade::Allowed-Origins {
  "${distro_id}:${distro_codename}-security";
  "${distro_id}ESMApps:${distro_codename}-apps-security";
  "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF
dpkg-reconfigure -f noninteractive unattended-upgrades

cat > /etc/fail2ban/jail.d/sshd.local <<'EOF'
[sshd]
enabled = true
bantime = 1h
findtime = 10m
maxretry = 5
backend = systemd
EOF

ufw default deny incoming
ufw default allow outgoing
ufw limit OpenSSH
ufw --force enable

systemctl enable --now ssh chrony fail2ban auditd
echo "Bootstrap concluído. Abra uma NOVA sessão SSH como $ADMIN_USER e execute scripts/15-validate-admin.sh com sudo."
