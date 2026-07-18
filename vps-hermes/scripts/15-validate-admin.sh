#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { echo "Execute com sudo a partir da nova sessão administrativa." >&2; exit 1; }
: "${ADMIN_USER:?Defina ADMIN_USER}"
[[ ${SUDO_USER:-} == "$ADMIN_USER" ]] || {
  echo "Este teste deve ser iniciado por $ADMIN_USER usando sudo, não diretamente como root." >&2
  exit 1
}
id -nG "$ADMIN_USER" | grep -qw sudo || { echo "$ADMIN_USER não pertence ao grupo sudo." >&2; exit 1; }

install -d -m 0700 /var/lib/hako
printf '%s\n' "validated_by=$ADMIN_USER" "validated_at=$(date -u +%FT%TZ)" \
  > /var/lib/hako/admin-sudo-validated
chmod 0600 /var/lib/hako/admin-sudo-validated
echo "OK: SSH por chave e sudo de $ADMIN_USER foram comprovados nesta nova sessão."
