# Delivery gates

## Before coding

- Objective and acceptance criteria are explicit.
- Repository and allowed write paths are explicit.
- Existing instructions, manifests, lockfiles, CI, and tests were inspected.
- Required credentials are referenced by name, never printed.

## Before dependency changes

- Explain why the existing stack is insufficient.
- Pin versions and preserve the lockfile.
- Review install scripts and lifecycle hooks.
- Run vulnerability and license checks appropriate to the ecosystem.

## Before deployment

- Tests, build, lint, migrations, healthcheck, observability, backup, and rollback are defined.
- Service, port, domain, secrets, resource limits, and owner are recorded.
- No application binds publicly unless explicitly designed and approved.
- Obtain operator approval for deploy, DNS, proxy, firewall, systemd, database migration, or cost.

## After deployment

- Verify the healthcheck from the intended network boundary.
- Inspect bounded logs without exposing secrets.
- Record deployed commit and exact rollback target.
- Do not declare success from process state alone.
