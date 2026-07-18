#!/usr/bin/env bash
set -Eeuo pipefail

fail=0
check() { if "$@"; then printf 'OK   %s\n' "$*"; else printf 'FAIL %s\n' "$*"; fail=1; fi; }

check systemctl is-active --quiet ssh
check systemctl is-active --quiet fail2ban
check systemctl is-active --quiet chrony
check systemctl is-enabled --quiet unattended-upgrades
check ufw status
check test -x /usr/local/bin/hermes
check test "$(id -u hermes)" -ne 0
check test ! -s /etc/sudoers.d/hermes
check sudo -u hermes -H /usr/local/bin/hermes doctor

ss -lntup
echo "Lembrete: valide backup externo, alertas e recuperação VNC no painel da Contabo."
exit "$fail"
