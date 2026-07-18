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
check test "$(stat -c %U /usr/local/bin/hermes)" = root
check test ! -L /usr/local/bin/hermes
check test ! -e /usr/local/bin/node
check test ! -e /usr/local/bin/npm
check test ! -e /usr/local/bin/npx
check sudo -u hermes -H /usr/local/bin/hermes version
if /usr/local/bin/hermes version >/dev/null 2>&1; then
  echo "FAIL /usr/local/bin/hermes aceitou execução privilegiada"
  fail=1
else
  echo "OK   /usr/local/bin/hermes recusa execução privilegiada"
fi
check sudo -u hermes -H /usr/local/bin/hermes doctor

ss -lntup
echo "Lembrete: valide backup externo, alertas e recuperação VNC no painel da Contabo."
exit "$fail"
