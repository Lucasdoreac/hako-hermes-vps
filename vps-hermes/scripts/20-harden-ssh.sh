#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { echo "Execute como root." >&2; exit 1; }
: "${ADMIN_USER:?Defina ADMIN_USER}"
key_file="/home/$ADMIN_USER/.ssh/authorized_keys"
[[ -s $key_file ]] || { echo "Chave de $ADMIN_USER não encontrada; abortando." >&2; exit 1; }
id -nG "$ADMIN_USER" | grep -qw sudo || { echo "$ADMIN_USER não possui sudo; abortando." >&2; exit 1; }
grep -qx "validated_by=$ADMIN_USER" /var/lib/hako/admin-sudo-validated 2>/dev/null || {
  echo "Sudo ainda não foi validado numa nova sessão. Execute scripts/15-validate-admin.sh como $ADMIN_USER." >&2
  exit 1
}

install -d -m 0755 /etc/ssh/sshd_config.d
# OpenSSH usa o primeiro valor encontrado. O prefixo 00 garante precedência
# sobre arquivos de cloud-init, que podem reativar PasswordAuthentication.
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
rm -f /etc/ssh/sshd_config.d/90-hako-hardening.conf

sshd -t
effective=$(/usr/sbin/sshd -T)
grep -qx 'permitrootlogin no' <<<"$effective"
grep -qx 'passwordauthentication no' <<<"$effective"
grep -qx 'authenticationmethods publickey' <<<"$effective"
systemctl reload ssh
echo "SSH endurecido. Mantenha esta sessão aberta e teste outra conexão imediatamente."
