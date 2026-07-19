#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { echo "Execute como root." >&2; exit 1; }
id hermes >/dev/null 2>&1 || { echo "Usuário hermes ausente." >&2; exit 1; }

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workspace=/srv/hermes-work
backup=/var/backups/hermes/showcase-pre-$(date -u +%Y%m%dT%H%M%SZ)
install -d -m 0700 "$backup"
for path in "$workspace/AGENTS.md" "$workspace/runbooks"; do
  [[ -e $path ]] && cp -a "$path" "$backup/"
done

install -d -m 0750 -o hermes -g hermes \
  "$workspace/projects/showcase-native" \
  "$workspace/projects/showcase-container" \
  "$workspace/runbooks"
install -m 0640 -o hermes -g hermes "$repo_root/assets/workspace/AGENTS.md" "$workspace/AGENTS.md"
install -m 0640 -o hermes -g hermes "$repo_root/assets/workspace/runbooks/deploy.md" "$workspace/runbooks/deploy.md"

cat > "$workspace/projects/showcase-native/AGENTS.md" <<'EOF'
# Showcase nativo

Projeto demonstrativo sem contêiner. Pode editar e testar livremente neste diretório. O deploy
usa um serviço systemd do usuário hermes e escuta apenas em 127.0.0.1:18080.
EOF
cat > "$workspace/projects/showcase-native/server.py" <<'EOF'
from http.server import BaseHTTPRequestHandler, HTTPServer
import json

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps({"service": "showcase-native", "status": "ok"}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *_):
        pass

HTTPServer(("127.0.0.1", 18080), Handler).serve_forever()
EOF

install -d -m 0700 -o hermes -g hermes /home/hermes/.config/systemd/user
cat > /home/hermes/.config/systemd/user/showcase-native.service <<EOF
[Unit]
Description=HAKO native showcase
After=network.target
[Service]
WorkingDirectory=$workspace/projects/showcase-native
ExecStart=/usr/bin/python3 $workspace/projects/showcase-native/server.py
Restart=on-failure
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=$workspace/projects/showcase-native
[Install]
WantedBy=default.target
EOF

cat > "$workspace/projects/showcase-container/AGENTS.md" <<'EOF'
# Showcase em contêiner

Projeto demonstrativo para Docker rootless. Não use sudo, grupo docker, modo privilegiado,
socket do Docker do host, dispositivos ou montagens fora deste projeto.
EOF
cat > "$workspace/projects/showcase-container/compose.yaml" <<'EOF'
services:
  web:
    image: nginx:1.29-alpine
    ports:
      - "127.0.0.1:18081:8080"
    volumes:
      - ./index.html:/usr/share/nginx/html/index.html:ro
      - ./default.conf:/etc/nginx/conf.d/default.conf:ro
    read_only: true
    tmpfs:
      - /var/cache/nginx
      - /var/run
      - /tmp
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    restart: unless-stopped
EOF
cat > "$workspace/projects/showcase-container/default.conf" <<'EOF'
server { listen 8080; location / { root /usr/share/nginx/html; } }
EOF
cat > "$workspace/projects/showcase-container/index.html" <<'EOF'
<!doctype html><meta charset="utf-8"><title>HAKO showcase</title><h1>Container rootless funcionando</h1>
EOF

chown -R hermes:hermes "$workspace" /home/hermes/.config/systemd/user
find "$workspace" -type d -exec chmod 0750 {} +
find "$workspace" -type f -exec chmod 0640 {} +
chmod 0750 "$workspace/projects/showcase-native/server.py"

loginctl enable-linger hermes
uid=$(id -u hermes)
sudo -u hermes XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user daemon-reload
sudo -u hermes XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user enable --now showcase-native.service
curl --fail --silent http://127.0.0.1:18080/
echo
echo "Showcase nativo ativo. O projeto container foi preparado, mas Docker rootless não foi instalado automaticamente."
echo "Backup pré-mudança: $backup"

