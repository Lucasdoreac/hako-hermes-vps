#!/usr/bin/env bash
set -euo pipefail

umask 077

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
out="${1:-hako-creative-preflight-${stamp}.txt}"

section() {
  printf '\n===== %s =====\n' "$1"
}

run() {
  printf '\n$ %q' "$1"
  shift || true
  for arg in "$@"; do printf ' %q' "$arg"; done
  printf '\n'
  "$@" 2>&1 || true
}

{
  echo "HAKO Creative clean restart — preflight somente leitura"
  echo "generated_at_utc=${stamp}"
  echo "host=$(hostname -f 2>/dev/null || hostname)"
  echo "user=$(id -un)"

  section "Sistema"
  uname -a || true
  cat /etc/os-release 2>/dev/null || true
  uptime || true
  timedatectl 2>/dev/null || true

  section "CPU e memória"
  lscpu 2>/dev/null || true
  free -h || true
  swapon --show 2>/dev/null || true

  section "Discos e filesystems"
  lsblk -o NAME,FSTYPE,SIZE,FSAVAIL,FSUSE%,MOUNTPOINTS 2>/dev/null || true
  df -hT || true
  df -ih || true

  section "GPU"
  command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi || echo "nvidia-smi indisponível"
  command -v lspci >/dev/null 2>&1 && lspci | grep -Ei 'vga|3d|display' || true

  section "Versões"
  for cmd in python3 python node npm ffmpeg ffprobe chromium chromium-browser google-chrome psql pg_dump n8n hermes; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf '%-20s ' "$cmd"
      "$cmd" --version 2>&1 | head -n 3 || true
    else
      printf '%-20s %s\n' "$cmd" "não encontrado no PATH"
    fi
  done

  section "Units relevantes"
  systemctl list-unit-files --no-pager 2>/dev/null | grep -Ei '(^|\s)(hako|hermes|n8n|postgresql)' || true
  systemctl list-units --all --no-pager 2>/dev/null | grep -Ei '(^|\s)(hako|hermes|n8n|postgresql)' || true

  section "Portas em escuta"
  ss -lntup 2>/dev/null || ss -lnt 2>/dev/null || true

  section "Processos relevantes"
  ps -eo user,pid,ppid,etimes,%cpu,%mem,cmd --sort=-%cpu | grep -Ei 'hako|hermes|n8n|postgres|node|python|ffmpeg|chrom' | grep -v grep || true

  section "Usuários e grupos relacionados"
  getent passwd | grep -Ei 'hako|hermes|n8n|postgres' || true
  getent group | grep -Ei 'hako|hermes|n8n|postgres' || true

  section "Diretórios relevantes"
  for root in /srv /opt /var/lib /etc; do
    if [[ -d "$root" ]]; then
      find "$root" -maxdepth 3 \( -iname '*hako*' -o -iname '*hermes*' -o -iname '*n8n*' \) -printf '%M %u:%g %s %TY-%Tm-%TdT%TH:%TM:%TS %p\n' 2>/dev/null || true
    fi
  done

  section "Backups visíveis"
  for root in /var/backups /srv/backups /opt/backups; do
    if [[ -d "$root" ]]; then
      find "$root" -maxdepth 3 -type f -printf '%s %TY-%Tm-%TdT%TH:%TM:%TS %p\n' 2>/dev/null | sort -nr | head -n 200 || true
    fi
  done

  section "Reboots e pacotes pendentes"
  [[ -f /var/run/reboot-required ]] && cat /var/run/reboot-required || echo "reboot-required não sinalizado"
  command -v apt >/dev/null 2>&1 && apt list --upgradable 2>/dev/null || true

  section "Firewall e proteção"
  command -v ufw >/dev/null 2>&1 && ufw status verbose 2>/dev/null || true
  command -v fail2ban-client >/dev/null 2>&1 && fail2ban-client status 2>/dev/null || true

  section "Resumo manual obrigatório"
  cat <<'EOF'
[ ] espaço para backup + duas releases + previews
[ ] restore de backup testado
[ ] serviços críticos e donos identificados
[ ] portas alvo livres ou justificadas
[ ] segredos localizados sem expor conteúdo
[ ] hardening permanece ativo
[ ] nenhuma alteração foi executada por este script
EOF
} | tee "$out"

printf '\nRelatório salvo em %s\n' "$out"
