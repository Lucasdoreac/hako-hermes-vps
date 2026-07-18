#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { echo "Execute como root." >&2; exit 1; }
: "${ADMIN_USER:?Defina ADMIN_USER}"
key_file="/home/$ADMIN_USER/.ssh/authorized_keys"
[[ -s $key_file ]] || { echo "Chave de $ADMIN_USER não encontrada; abortando." >&2; exit 1; }
id -nG "$ADMIN_USER" | grep -qw sudo || { echo "$ADMIN_USER não possui sudo; abortando." >&2; exit 1; }

install -d -m 0755 /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/90-hako-hardening.conf <<'EOF'
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

sshd -t
systemctl reload ssh
echo "SSH endurecido. Mantenha esta sessão aberta e teste outra conexão imediatamente."
