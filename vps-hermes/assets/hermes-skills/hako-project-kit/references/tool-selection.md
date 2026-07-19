# Tool selection

## Decision order

1. Built-in Hermes tool.
2. Project-local command already declared in a lockfile or manifest.
3. User-space CLI with a pinned version and no host mutation.
4. Skill wrapping a repeatable workflow.
5. MCP server when structured external API access is materially better than a CLI.
6. Administrator-installed host dependency only after approval.

## Choose the mechanism

| Need | Prefer | Avoid |
|---|---|---|
| Repository context | Hierarchical `AGENTS.md` | Global memory dump |
| Repeatable procedure | Skill | Huge permanent prompt |
| GitHub issues/PRs | GitHub CLI or filtered MCP | Broad token in shell history |
| Database inspection | Project-scoped read-only MCP | Production admin credentials |
| Browser verification | Built-in browser | Unpinned automation bundles |
| Language runtime | Project manifest + version manager | Replacing global system runtime |
| Build/test | Repository scripts | Ad-hoc commands only in chat |
| Deployment | Runbook + approved automation | Agent improvising on production |

## MCP admission checklist

- Name the project and exact bottleneck.
- Prefer an approved catalog entry.
- Pin stdio package versions; do not use floating `npx -y` in production.
- Pass only explicitly required environment variables.
- Filter tools to the minimum surface.
- Use project-scoped credentials with least privilege.
- Keep destructive tools disabled unless separately approved.
- Run the Hermes security audit after changes.
- Disable the MCP when the project no longer needs it.

## Large-project delegation

Delegate by bounded ownership such as frontend, API, migrations, tests, or documentation. Give each worker the nearest `AGENTS.md`, exact paths, acceptance tests, and a no-deploy boundary. Integrate centrally after reviewing diffs and tests.
