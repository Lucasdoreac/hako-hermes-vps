#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { echo "Execute como root." >&2; exit 1; }

cat > /etc/audit/rules.d/50-hako.rules <<'EOF'
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/sudoers -p wa -k privilege
-w /etc/sudoers.d/ -p wa -k privilege
-w /etc/ssh/sshd_config -p wa -k ssh
-w /etc/ssh/sshd_config.d/ -p wa -k ssh
-w /etc/systemd/system/ -p wa -k systemd
-w /usr/local/bin/hermes -p wa -k hermes
-w /home/hermes/.hermes/config.yaml -p wa -k hermes_config
-w /home/hermes/.hermes/.env -p wa -k hermes_secrets
EOF
chown root:root /etc/audit/rules.d/50-hako.rules
chmod 0640 /etc/audit/rules.d/50-hako.rules
augenrules --load
systemctl enable --now auditd

# aide-common usa o MTA apenas para alertas locais. Não aceite SMTP da internet.
if command -v postconf >/dev/null 2>&1; then
  postconf -e 'inet_interfaces = loopback-only'
  systemctl restart postfix
fi

if [[ ! -s /var/lib/aide/aide.db ]]; then
  aideinit -y -f
fi
systemctl enable --now dailyaidecheck.timer

auditctl -l
systemctl status dailyaidecheck.timer --no-pager
echo "Auditd e AIDE configurados. Revise alertas em /var/log/aide/ e journalctl."
