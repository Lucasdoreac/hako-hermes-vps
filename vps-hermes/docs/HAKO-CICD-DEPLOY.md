# CI/CD HAKO runtime → VPS — modelo de setup (proposta, não executado)

## Usuário de deploy na VPS (Etapa 3) — a executar com aprovação
```bash
# como root, uma vez:
adduser --system --group --shell /usr/sbin/nologin --home /home/hako-deploy hako-deploy
install -d -m 700 -o hako-deploy -g hako-deploy /home/hako-deploy/.ssh
# chave PÚBLICA de deploy (par gerado só para isto; a privada vai para o GitHub Environment):
printf '%s\n' "<CHAVE_PUBLICA_DEPLOY>" > /home/hako-deploy/.ssh/authorized_keys
chown hako-deploy:hako-deploy /home/hako-deploy/.ssh/authorized_keys
chmod 600 /home/hako-deploy/.ssh/authorized_keys
```
- Sem senha (conta `--system`, `nologin`); autenticação só por chave.
- `hako-deploy` NÃO pode editar o script de deploy (root:root 0755).

## sudoers — `/etc/sudoers.d/hako-deploy` (root:root, 0440)
```
# hako-deploy só pode invocar o script de deploy, nada de shell genérico.
hako-deploy ALL=(root) NOPASSWD: /usr/local/sbin/deploy-hako-runtime.sh
Defaults!/usr/local/sbin/deploy-hako-runtime.sh !requiretty
```
- NUNCA `NOPASSWD: ALL`. Só este binário. Validar com `visudo -cf /etc/sudoers.d/hako-deploy`.

## Script de deploy
- `deploy-hako-runtime.sh` → instalar em `/usr/local/sbin/`, `root:root`, `chmod 0755`.

## GitHub Environment `production` (Etapa 3)
Criar Environment `production` no repo `hako-creative-intelligence` com:
- **Required reviewers** habilitado (aprovação manual) na 1ª fase.
- Secrets (somente estes 5):
  | Secret | Conteúdo |
  |---|---|
  | `VPS_HOST` | IP público da VPS |
  | `VPS_PORT` | porta SSH |
  | `VPS_USER` | `hako-deploy` |
  | `VPS_SSH_KEY` | chave PRIVADA de deploy (par novo, exclusivo do CI) |
  | `VPS_HOST_KEY` | linha(s) de `known_hosts` reais do host |
- `VPS_HOST_KEY` obtém-se com `ssh-keyscan -p <porta> <host>` e conferindo o fingerprint.
- Nenhum outro segredo entra no CI. `DATABASE_URL`, token Telegram e Gemini vivem só em `/etc/hako-creative/*.env` (root:hako-creative 0640) — **nunca** no GitHub.

## Workflow
- `.github/workflows/deploy-vps.yml` → repo `hako-creative-intelligence`.
- Fase 1: só `workflow_dispatch`. Habilitar `push:[main]` só após deploy manual + rollback OK.

## Rollback
- Automático dentro do script (health falha → restaura symlink anterior + reinicia API/worker).
- Manual: `ls -1dt /srv/hako-creative/releases/*/` → escolher anterior →
  `sudo /usr/local/sbin/deploy-hako-runtime.sh <sha-do-release-anterior>` (re-deploy do SHA bom),
  ou repromover o symlink e reiniciar API+worker.

## Ordem de execução (gates)
1. Merge #31 e #32 em `hako-creative-intelligence` (CI `ciclo` verde).
2. Merge #9 em `hako-hermes-vps` (instalador + units + runbook).
3. Bootstrap na VPS pelo runbook do #9: usuário `hako-creative`, `/srv` e `/etc/hako-creative`,
   env files com valores reais, DB/usuário PostgreSQL, units instaladas, preflight verde.
4. Criar `hako-deploy` + sudoers + instalar `deploy-hako-runtime.sh`.
5. Criar Environment `production` + 5 secrets (par de chave novo).
6. 1º deploy manual (workflow_dispatch), **sem** `--enable-telegram` (mantém opção A: n8n consome o bot).
7. Testar rollback. Só então considerar `push:[main]`.
