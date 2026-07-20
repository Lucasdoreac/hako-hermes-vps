#!/usr/bin/env bash
set -euo pipefail

failures=0
warn() { printf 'WARN  %s\n' "$*"; }
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }

command -v systemctl >/dev/null && pass 'systemd disponível' || fail 'systemctl ausente'
command -v python3 >/dev/null && pass "$(python3 --version)" || fail 'python3 ausente'
command -v psql >/dev/null && pass "$(psql --version)" || fail 'psql ausente'
command -v ffmpeg >/dev/null && pass "$(ffmpeg -version | head -n1)" || warn 'ffmpeg ausente; preview estruturado funciona, render futuro não'

if id hako-creative >/dev/null 2>&1; then
  pass 'usuário hako-creative existe'
else
  fail 'usuário hako-creative ausente'
fi

for directory in \
  /srv/hako-creative/current \
  /srv/hako-creative/assets \
  /srv/hako-creative/cache \
  /srv/hako-creative/logs; do
  [[ -e "$directory" ]] && pass "$directory existe" || fail "$directory ausente"
done

if [[ -x /srv/hako-creative/current/.venv/bin/python ]]; then
  pass 'venv do release existe'
else
  fail 'venv ausente em /srv/hako-creative/current/.venv'
fi

for file in /etc/hako-creative/runtime.env /etc/hako-creative/telegram.env; do
  if [[ -f "$file" ]]; then
    mode="$(stat -c '%a' "$file")"
    owner="$(stat -c '%U:%G' "$file")"
    [[ "$mode" == '640' || "$mode" == '600' ]] && pass "$file modo $mode" || fail "$file modo inseguro $mode"
    [[ "$owner" == 'root:hako-creative' || "$owner" == 'root:root' ]] && pass "$file owner $owner" || fail "$file owner inesperado $owner"
    if grep -q 'REPLACE_' "$file"; then
      fail "$file ainda contém placeholders"
    fi
  else
    fail "$file ausente"
  fi
done

if [[ -f /etc/hako-creative/runtime.env ]]; then
  set -a
  # shellcheck disable=SC1091
  source /etc/hako-creative/runtime.env
  set +a
  if [[ -n "${DATABASE_URL:-}" ]]; then
    if psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -Atqc 'select 1' >/dev/null 2>&1; then
      pass 'PostgreSQL acessível pela role do runtime'
    else
      fail 'PostgreSQL inacessível pela DATABASE_URL configurada'
    fi
  else
    fail 'DATABASE_URL ausente'
  fi
fi

for unit in hako-creative-api.service hako-creative-worker.service hako-telegram-receiver.service; do
  if systemctl cat "$unit" >/dev/null 2>&1; then
    pass "$unit instalado"
  else
    fail "$unit não instalado"
  fi
done

if command -v ss >/dev/null; then
  if ss -ltnH | awk '{print $4}' | grep -Eq '(^|:)8099$'; then
    warn 'porta 8099 já está em uso; confirme se é o API esperado'
  else
    pass 'porta 8099 livre'
  fi
fi

if [[ -x /srv/hako-creative/current/.venv/bin/python ]]; then
  if sudo -u hako-creative --preserve-env=DATABASE_URL,HAKO_STORAGE_ROOT \
      /srv/hako-creative/current/.venv/bin/python -c \
      'from app.server import app; from app.control_intent import verify_intent_bytes; print("imports-ok")' \
      >/dev/null 2>&1; then
    pass 'imports do runtime funcionam como hako-creative'
  else
    fail 'imports do runtime falharam como hako-creative'
  fi
fi

if (( failures > 0 )); then
  printf '\nPRECHECK FALHOU: %d problema(s). Nenhum serviço foi alterado.\n' "$failures"
  exit 1
fi
printf '\nPRECHECK OK: ambiente pronto para smoke controlado.\n'
