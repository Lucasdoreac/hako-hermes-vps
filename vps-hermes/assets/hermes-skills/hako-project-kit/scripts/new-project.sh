#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  echo "Usage: $0 --name SLUG [--stack generic|python|node|fullstack] [--repo URL] [--domain DOMAIN] [--root DIR]"
}

name=
stack=generic
repo=
domain=
root=/srv/hermes-work/projects
while (($#)); do
  case "$1" in
    --name) name=${2:-}; shift 2 ;;
    --stack) stack=${2:-}; shift 2 ;;
    --repo) repo=${2:-}; shift 2 ;;
    --domain) domain=${2:-}; shift 2 ;;
    --root) root=${2:-}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ $name =~ ^[a-z0-9][a-z0-9-]{1,62}$ ]] || { echo "Invalid slug: $name" >&2; exit 2; }
case "$stack" in generic|python|node|fullstack) ;; *) echo "Unsupported stack: $stack" >&2; exit 2;; esac
[[ -z $domain || $domain =~ ^[A-Za-z0-9.-]+$ ]] || { echo "Invalid domain" >&2; exit 2; }

target=$root/$name
[[ ! -e $target ]] || { echo "Project already exists: $target" >&2; exit 1; }
install -d -m 0750 "$root"
stage=$(mktemp -d "$root/.${name}.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
install -d -m 0750 "$stage/docs" "$stage/scripts" "$stage/.hako"

cat > "$stage/AGENTS.md" <<EOF
# $name

## Scope

Work only in this repository. Read manifests, lockfiles, CI and the nearest subsystem AGENTS.md before editing.

## Stack

- Type: $stack
- Domain: ${domain:-not assigned}
- Repository: ${repo:-not assigned}

## Gates

- A question is not authorization to install, deploy, delete, publish or incur cost.
- Keep secrets outside Git and never print them.
- Run declared tests before proposing deployment.
- Deployment, migrations, DNS, proxy, firewall and system services require operator approval.
- Report changed files, tests, risks and rollback.
EOF

cat > "$stage/.hako/project.env.example" <<EOF
PROJECT_NAME=$name
PROJECT_STACK=$stack
PROJECT_DOMAIN=${domain}
SERVICE_PORT=
HEALTHCHECK_URL=
EOF

cat > "$stage/docs/architecture.md" <<'EOF'
# Architecture

Record components, boundaries, data stores, external services and important decisions here.
EOF
cat > "$stage/docs/development.md" <<'EOF'
# Development

Record prerequisites and canonical setup, test, lint and build commands here.
EOF
cat > "$stage/docs/deployment.md" <<'EOF'
# Deployment

Deployment is not authorized by this file. Record service, port, domain, secrets source,
healthcheck, migration plan, observability and exact rollback before requesting approval.
EOF

case "$stack" in
  python) printf '[tools]\npython = "3.11"\n' > "$stage/mise.toml" ;;
  node) printf '[tools]\nnode = "lts"\n' > "$stage/mise.toml" ;;
  fullstack) printf '[tools]\npython = "3.11"\nnode = "lts"\n' > "$stage/mise.toml" ;;
esac

git -C "$stage" init -q
git -C "$stage" branch -M main
if [[ -n $repo ]]; then git -C "$stage" remote add origin "$repo"; fi
mv -- "$stage" "$target"
trap - EXIT
echo "Created $target"
echo "Next: inspect AGENTS.md, define acceptance tests, then select only the required tools."
