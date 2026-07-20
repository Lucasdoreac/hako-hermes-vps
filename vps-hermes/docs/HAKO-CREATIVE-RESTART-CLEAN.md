# Runbook — restart clean do HAKO Creative

> Este runbook prepara o host. Ele não autoriza destruição de dados nem deploy automático pelo chat.

## Objetivo

Preservar o hardening e o Hermes existentes, arquivar qualquer runtime experimental e criar uma base isolada para o HAKO Creative v0.

O domínio do produto está definido no `hako-creative-intelligence` PR R0. Este documento cobre somente o host.

## Regras de segurança

- não reinstalar Ubuntu;
- não remover Hermes;
- não apagar banco, diretório, unit ou segredo sem backup verificado;
- não dar root permanente ao Hermes;
- não expor portas publicamente no primeiro corte;
- não reutilizar silenciosamente schema ou diretório experimental;
- não conectar Telegram, Meta ou providers antes do smoke por API local;
- cada etapa registra estado anterior, estado posterior e rollback.

## Fase P0 — inventário somente leitura

Execute `vps-hermes/scripts/hako-creative-preflight.sh` como usuário administrativo normal e arquive o relatório.

Confirmar manualmente:

- CPU, RAM, swap, disco e filesystem;
- presença/ausência de GPU;
- versões de Ubuntu, kernel, Python, Node, npm, FFmpeg, Chromium, PostgreSQL, n8n e Hermes;
- units `hako-*`, `hermes*`, `n8n*` e `postgresql*`;
- processos e portas em escuta;
- usuários e grupos relacionados;
- diretórios existentes em `/srv`, `/opt` e `/var/lib`;
- política atual de backup e espaço para rollback.

### Stop conditions

Pare antes de qualquer alteração se:

- disco livre for insuficiente para backup + duas releases + previews;
- backup atual não puder ser restaurado em teste;
- houver serviço crítico sem dono identificado;
- uma porta alvo já estiver ocupada por serviço desconhecido;
- o host estiver com atualização/reboot crítico pendente;
- o inventário não identificar onde segredos atuais estão armazenados.

## Fase P1 — snapshot e arquivo

Antes de parar serviços:

```bash
sudo systemctl list-unit-files 'hako-*' 'hermes*' 'n8n*' 'postgresql*'
sudo systemctl status 'hako-*' --no-pager || true
sudo ss -lntup
```

Para cada banco experimental identificado:

```bash
sudo -u postgres pg_dump --format=custom --file=/var/backups/hako/<db>-<timestamp>.dump <db>
pg_restore --list /var/backups/hako/<db>-<timestamp>.dump >/dev/null
```

Para cada diretório experimental identificado:

```bash
sudo tar --xattrs --acls --numeric-owner \
  -C / \
  -czf /var/backups/hako/<name>-<timestamp>.tar.gz \
  <path-sem-barra-inicial>
```

Registrar checksums:

```bash
sha256sum /var/backups/hako/*<timestamp>* | sudo tee /var/backups/hako/SHA256SUMS-<timestamp>
```

Somente depois da verificação, parar units experimentais. Não apagar as units; movê-las para arquivo e executar `systemctl daemon-reload`.

## Fase P2 — identidades isoladas

Criar identidades sem login e sem sudo:

```text
hako-api
hako-worker
hako-render
```

Cada serviço recebe apenas os grupos estritamente necessários. O usuário `hermes` não é adicionado a esses grupos por padrão.

Diretórios alvo:

```text
/srv/hako-creative/releases
/srv/hako-creative/current
/srv/hako-creative/assets
/srv/hako-creative/previews
/srv/hako-creative/renders
/srv/hako-creative/cache
/srv/hako-creative/logs
/etc/hako-creative
```

Regras:

- código/release: root-owned, leitura para serviço;
- assets e previews: escrita apenas pelos workers necessários;
- segredos: root-owned, modo mínimo, arquivo separado por serviço;
- `current` aponta para uma release imutável;
- rollback troca o symlink e reinicia a unit correspondente.

## Fase P3 — banco novo

Criar banco e role novos:

```text
database: hako_creative_v0
role: hako_creative
```

Não restaurar automaticamente o schema experimental. Dumps antigos permanecem em arquivo para inspeção e migração explícita.

No primeiro corte, PostgreSQL mantém estado e fila por `FOR UPDATE SKIP LOCKED`. Redis não é requisito.

## Fase P4 — units mínimas

Criar somente quando o R1 do produto existir:

```text
hako-api.service
hako-worker.service
hako-render.service
```

Propriedades mínimas:

```ini
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
LockPersonality=true
MemoryDenyWriteExecute=true
```

`ReadWritePaths` deve listar apenas os diretórios necessários. Definir limites de memória, CPU, processos, arquivos abertos, timeout e política de restart por serviço.

A API escuta somente em loopback.

## Fase P5 — ordem do smoke

A primeira validação operacional ocorre nesta ordem:

1. PostgreSQL e migration;
2. `GET /health` local;
3. `POST /batches` por HTTP local;
4. job persistido;
5. worker consome o job;
6. dez `variant_specs` persistidas;
7. dez previews baratos;
8. feedback enviado por HTTP;
9. regeneração seletiva;
10. verificação de linhagem e idempotência;
11. reinício controlado de API/worker para provar recuperação;
12. queda/desconexão do Hermes para provar independência.

Telegram/Hermes entra somente depois desse smoke.

## Fase P6 — adapter de operador

Após R1–R5:

- bot HAKO separado;
- token fora do Git;
- allowlist;
- texto, áudio, anexos e replies;
- correlação com variante/asset;
- Hermes pode interpretar instrução natural;
- runtime valida e persiste a requisição;
- API HTTP interna é fallback obrigatório;
- bot-to-bot é experimento de borda.

## Fase P7 — pacote Premiere

O host gera assets e pacote de acabamento. O Premiere permanece na estação do operador.

O pacote deve incluir manifest, timeline neutra, mídia, SRT, previews, cores, fontes e notas de edição.

DaVinci MCP não é instalado no caminho principal. Permanece spike posterior, sem orientar dados ou serviços.

## Rollback

Cada release deve registrar:

- commit e tag;
- migration aplicada;
- backup anterior;
- units alteradas;
- symlink anterior;
- healthcheck esperado;
- comando de rollback.

Rollback padrão:

1. parar somente a unit afetada;
2. reverter migration apenas se houver procedimento testado; caso contrário, restaurar banco em instância separada;
3. apontar `current` para release anterior;
4. restaurar arquivo de ambiente anterior;
5. iniciar unit;
6. verificar healthcheck e logs;
7. registrar incidente.

## Critério de host pronto

- inventário e backups verificados;
- nenhuma perda de hardening;
- identidades isoladas criadas;
- banco novo disponível;
- diretórios e ACLs revisados;
- units somente em loopback;
- rollback testado;
- smoke API → banco → worker → previews → feedback → regeneração aprovado;
- jobs persistidos sobrevivem à indisponibilidade do Hermes;
- nenhum canal externo ou publicação automática habilitado.
