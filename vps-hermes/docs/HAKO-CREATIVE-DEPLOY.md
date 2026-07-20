# Deploy do HAKO Creative restart clean

Este runbook prepara o runtime sem reinstalar Ubuntu e sem conceder sudo ao Hermes.

## Topologia

```text
hako-creative-api.service       loopback :8099
hako-creative-worker.service    filas PostgreSQL R1–R7
hako-telegram-receiver.service  novo bot HAKO; long polling
PostgreSQL                      fonte de verdade
/srv/hako-creative/assets       object store local content-addressed
```

O bot Hermes existente mantém sua configuração e token. O novo bot HAKO usa token próprio. O segredo HMAC compartilhado autoriza somente quatro control intents do domínio; não concede shell, banco ou filesystem.

## 1. Inventário e backup

Antes de alterar o host:

```bash
sudo systemctl list-unit-files 'hako-*'
sudo ss -lntup
sudo -u postgres pg_dump --format=custom --file=/var/backups/hako-before-restart.dump hako_creative || true
sudo tar -C /srv -czf /var/backups/hako-creative-before-restart.tgz hako-creative 2>/dev/null || true
```

Registre CPU, RAM, disco, versões de Python, PostgreSQL, Node, FFmpeg e Hermes.

## 2. Checkout revisado

Use um commit/merge conhecido de `hako-creative-intelligence`. Não implante branch de pesquisa ou PR draft.

```bash
git clone https://github.com/Lucasdoreac/hako-creative-intelligence.git /tmp/hako-creative-release
cd /tmp/hako-creative-release
git checkout <MERGE_SHA_APROVADO>
```

## 3. Preparação sem start

A partir do checkout deste repositório VPS:

```bash
sudo vps-hermes/scripts/install-hako-runtime.sh /tmp/hako-creative-release
```

Isso cria release versionado, venv, usuário, diretórios, env skeletons e units. Não migra nem inicia.

## 4. Segredos e banco

Edite:

```text
/etc/hako-creative/runtime.env
/etc/hako-creative/telegram.env
```

Permissões esperadas:

```bash
sudo chown root:hako-creative /etc/hako-creative/*.env
sudo chmod 0640 /etc/hako-creative/*.env
```

Crie banco/role dedicados. Exemplo, adaptado à política local:

```sql
CREATE ROLE hako_creative LOGIN PASSWORD '<senha-forte>';
CREATE DATABASE hako_creative_v0 OWNER hako_creative;
REVOKE ALL ON DATABASE hako_creative_v0 FROM PUBLIC;
```

Não copie tokens para Git, issue, PR, log ou memória geral do Hermes.

## 5. Novo bot HAKO

No BotFather:

1. crie um bot separado;
2. mantenha o bot Hermes atual intacto;
3. habilite o modo privado bot-to-bot nos dois bots para o spike;
4. obtenha IDs numéricos do operador, bot Hermes e bot HAKO;
5. preencha as allowlists com IDs, nunca apenas usernames.

O receiver rejeita bot sem `hako-intent.json` assinado, mesmo se o texto parecer um comando.

## 6. Migração e preflight

```bash
sudo vps-hermes/scripts/install-hako-runtime.sh /tmp/hako-creative-release --migrate
sudo vps-hermes/scripts/hako-runtime-preflight.sh
```

O preflight não altera serviços.

## 7. Start sem Telegram

Primeiro prove API + worker:

```bash
sudo vps-hermes/scripts/install-hako-runtime.sh /tmp/hako-creative-release --start
curl --fail --silent http://127.0.0.1:8099/health | jq
sudo journalctl -u hako-creative-api -u hako-creative-worker -n 100 --no-pager
```

Crie um batch por HTTP loopback e confirme os dez previews antes de ativar canal.

## 8. Start do receiver

Quando token, IDs, segredo e bot-to-bot estiverem validados:

```bash
sudo vps-hermes/scripts/install-hako-runtime.sh /tmp/hako-creative-release --start --enable-telegram
sudo journalctl -u hako-telegram-receiver -f
```

Faça primeiro um teste humano allowlisted. Depois envie uma intent assinada de `create_batch` pelo bot Hermes. Não comece por regeneração/aprovação.

## 9. Smoke de aceitação

1. texto humano é persistido e não executa ação;
2. bot Hermes sem documento assinado é rejeitado;
3. intent assinada cria um batch uma vez;
4. replay do mesmo `command_id` não duplica;
5. worker produz `v00`–`v09`;
6. previews possuem checksums distintos;
7. feedback de cena cria proposta;
8. aprovação separada cria um job;
9. revisão preserva cenas não afetadas;
10. pacote Premiere aponta para o preview pai.

## Rollback

Cada deploy cria `/srv/hako-creative/releases/<timestamp>-<sha>`.

```bash
sudo systemctl stop hako-telegram-receiver hako-creative-worker hako-creative-api
sudo ln -sfn /srv/hako-creative/releases/<RELEASE_ANTERIOR> /srv/hako-creative/current
sudo systemctl start hako-creative-api hako-creative-worker
```

Não reverta migrations destrutivamente durante incidente. Restaure o dump em banco separado, compare e decida conscientemente.

## Fora deste deploy

- renderer R4 até decisão medida;
- Meta/WhatsApp;
- publicação automática;
- Premiere/UXP no VPS;
- DaVinci MCP;
- `hako-core`;
- root/sudo para Hermes.
