#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { echo "Execute com sudo." >&2; exit 1; }
umask 077

output=${1:-/home/lucas/hako-vps-audit-$(date -u +%Y%m%dT%H%M%SZ).txt}
exec > >(tee "$output") 2>&1

section() { printf '\n## %s\n' "$1"; }

section "Identidade e sistema"
date -Is
hostnamectl
uname -a
uptime

section "Contas administrativas e chaves autorizadas"
getent group sudo
for user_name in root ubuntu lucas hermes; do
  home=$(getent passwd "$user_name" | cut -d: -f6)
  shell=$(getent passwd "$user_name" | cut -d: -f7)
  printf '%s home=%s shell=%s\n' "$user_name" "$home" "$shell"
  if [[ -f $home/.ssh/authorized_keys ]]; then
    stat -c '%A %U:%G %n' "$home" "$home/.ssh" "$home/.ssh/authorized_keys"
    ssh-keygen -lf "$home/.ssh/authorized_keys"
  else
    echo "authorized_keys ausente"
  fi
  sudo -l -U "$user_name" 2>/dev/null || true
done

section "SSH efetivo"
/usr/sbin/sshd -T | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication|permitemptypasswords|x11forwarding|allowtcpforwarding|gatewayports|maxauthtries|logingracetime) '

section "Rede e firewall"
ss -lntup
ufw status verbose
nft list ruleset
fail2ban-client status
fail2ban-client status sshd || true

section "Serviços e falhas"
systemctl --failed --no-pager
systemctl list-units --type=service --state=running --no-pager
systemctl status hermes-backup.service hako-restic-backup.service --no-pager || true
journalctl -u hermes-backup.service -u hako-restic-backup.service -n 100 --no-pager

section "Hermes e permissões"
stat -c '%A %U:%G %n' /home/hermes /home/hermes/.hermes \
  /home/hermes/.hermes/.env /home/hermes/.hermes/config.yaml
find /home/hermes/.config/systemd/user -maxdepth 1 -type f -printf '%M %u:%g %p\n' 2>/dev/null || true
find /usr/local/bin -maxdepth 1 -type l -printf '%p -> %l\n'
runuser -u hermes -- /usr/local/bin/hermes doctor || true

section "Auditoria e integridade"
auditctl -s
auditctl -l
find /var/lib/aide -maxdepth 1 -type f -printf '%M %u:%g %s %y %p\n'
systemctl status dailyaidecheck.service dailyaidecheck.timer --no-pager || true
journalctl -u dailyaidecheck.service -n 50 --no-pager

section "Atualizações e persistência"
apt list --upgradable 2>/dev/null || true
systemctl list-timers --all --no-pager
find /etc/systemd/system /usr/local /opt -xdev -type f -perm -0002 -printf '%M %u:%g %p\n' 2>/dev/null

section "Logins recentes"
last -n 30 -w
journalctl -u ssh.service --since '7 days ago' --no-pager | grep -E 'Accepted|Failed|Invalid|error' | tail -n 200 || true

chmod 600 "$output"
echo "Relatório: $output"
