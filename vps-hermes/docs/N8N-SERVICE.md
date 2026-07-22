# n8n na VPS — serviço, persistência e operação

O n8n orquestra o produto HAKO Creative e roda **no mesmo host**, em loopback. Este
documento registra como ele está provisionado hoje, porque até 22/07/2026 essa
configuração existia **apenas na máquina** — reprovisionar a VPS não a reconstruía.

O **papel** do n8n (orquestrador visível sobre o runtime, não executor) foi decidido no
ADR-016 do repo de produto (#51). O **dono do serviço** — conta humana `lucas` vs. usuário
técnico dedicado — era a decisão em aberto abaixo, agora **fechada** em favor da migração para
um usuário de sistema (ver "Migração para usuário isolado").

## Como roda (estado atual, antes da migração)

Unit **`systemd --user`** do usuário `lucas`, não unit de sistema:

| Fato | Valor | Como conferir |
|---|---|---|
| Unit | `n8n.service` (usuário) | `systemctl --user status n8n` |
| Habilitada no boot | sim | `systemctl --user is-enabled n8n` → `enabled` |
| Linger | sim | `loginctl show-user lucas -p Linger` → `Linger=yes` |
| Reinício automático | `Restart=always`, `RestartSec=5` | `systemd/user/n8n.service` |
| Escuta | `127.0.0.1:5678` (UI) e `127.0.0.1:5679` (task broker) | `ss -ltnp` |
| Dados | `~lucas/.n8n` (`0700`), SQLite `0600` | `stat -c '%A' ~/.n8n` |

O arquivo versionado em `systemd/user/n8n.service` é **cópia fiel do instalado**.
Confira antes de confiar nele:

```bash
sha256sum ~/.config/systemd/user/n8n.service
sha256sum vps-hermes/systemd/user/n8n.service   # devem bater
```

Nenhum segredo mora na unit: as onze `Environment=` são configuração de loopback
(host, porta, protocolo, timezone, diagnóstico desligado). O
`N8N_ENCRYPTION_KEY` fica em `~/.n8n/config`, modo `0600`, **fora do Git** — é ele
que decifra as credenciais guardadas no cofre do n8n.

## Persistência após reboot

`enabled` + `WantedBy=default.target` + `linger=yes` é a combinação completa: o
user manager de `lucas` sobe sem login e arrasta a unit junto.

**A configuração está provada; o comportamento não.** Em 22/07/2026 o último boot
era de 19/07 03:39 e o processo tinha subido em 20/07 01:41 — ou seja, a unit
nunca passou por um boot real. Só um reboot controlado fecha isso, e ele não foi
feito de propósito: a instância em pé era a única que funcionava.

## Como *não* diagnosticar

`systemctl list-unit-files | grep n8n` volta **vazio**, e `systemctl is-active n8n`
diz `inactive`. Os dois são verdadeiros e os dois enganam: consultam o gerenciador
de **sistema**, e o n8n não está lá. Essa leitura já produziu o diagnóstico errado
de "processo solto que não sobrevive a reboot".

O sinal que não mente é o cgroup:

```bash
cat /proc/$(pgrep -f 'n8n start')/cgroup
# 0::/user.slice/user-1001.slice/user@1001.service/app.slice/n8n.service
```

Sempre consulte também `systemctl --user` (ver `scripts/hako-creative-preflight.sh`).

## Executar workflows pela CLI com o serviço no ar

`n8n execute` e `n8n import:workflow` tentam subir o **próprio task broker** na
porta padrão `5679`, já ocupada pelo serviço. O erro é:

```
n8n Task Broker's port 5679 is already in use. Do you have another instance of n8n running already?
```

A mensagem não sugere a saída. Use uma porta alternativa, em loopback:

```bash
export N8N_RUNNERS_BROKER_PORT=5690
export N8N_RUNNERS_BROKER_LISTEN_ADDRESS=127.0.0.1
n8n execute --id=<WORKFLOW_ID>
```

Outra pegadinha da CLI: **`import:workflow` não restaura vínculo de credencial.**
Workflows exportados trazem `credentials.<tipo>.id` vazio (é assim que devem ser
versionados num repo público), e após o import os nós ficam sem credencial. Religue
na UI ou injete o id no JSON antes de importar — e nunca commite o JSON com o id
dentro.

## Decisão tomada: dono do serviço → usuário isolado

Hoje o n8n depende da conta humana `lucas`. Se ela for removida, perder o linger ou
tiver o `~/.local/node` alterado, o serviço cai. Isso contrasta com o runtime HAKO,
que roda em units de sistema sob `hako-creative` (`nologin`), conforme ADR-001 do
repositório de produto.

**Decisão (22/07/2026):** migrar para um usuário técnico dedicado `hako-n8n`
(`nologin`) com unit de **sistema** (`systemd/hako-n8n.service`), alinhando o n8n ao
runtime e fechando o ADR-008 na prática. O que a mantinha aberta não era dúvida de
rumo, e sim o **risco de execução**: o `N8N_ENCRYPTION_KEY` vive em `~/.n8n/config` e
precisa migrar **junto** com o `~/.n8n`, senão todas as credenciais do cofre viram
lixo cifrado. Por isso a migração é um passo de manutenção deliberado, não parte do
deploy — com backup e verificação da chave, nunca às pressas.

## Migração para usuário isolado (runbook)

O script `scripts/migrate-n8n-to-system-user.sh` faz a migração de forma idempotente,
preservando a chave e abortando se ela não bater no destino. Ele **não** roda em
deploy: exige `--cutover` explícito, numa janela de manutenção.

```bash
# 1. Ensaie sem mudar nada — valida pre-condicoes e mostra o plano:
sudo vps-hermes/scripts/migrate-n8n-to-system-user.sh --check

# 2. Execute a migracao (para o n8n antigo, faz backup de ~/.n8n com a chave,
#    cria hako-n8n, copia dados+node, VERIFICA a chave, instala e sobe a unit):
sudo vps-hermes/scripts/migrate-n8n-to-system-user.sh --cutover

# 3. Confirme que agora e unit de sistema sob hako-n8n:
systemctl status hako-n8n
cat /proc/"$(pgrep -f 'n8n start')"/cgroup    # deve citar hako-n8n.service, nao user@
ss -ltnp | grep 5678
```

O backup fica em `/srv/hako-n8n-backups/n8n-<timestamp>.tgz` (inclui a chave; `0600`,
fora do Git). Em qualquer falha, o script religa o n8n antigo de `lucas` e preserva o
backup — nenhuma porta em conflito. Depois de estável, o linger de `lucas` pode ser
revisto separadamente (não é removido pela migração, para não afetar outros serviços
de usuário).

## Remover o workflow órfão da instância

A reconciliação (`tools/n8n_reconcile.py` no repo de produto) achou **1 workflow na
instância que não existe no repositório** e estava inativo — `ausente_no_repo`. Remova-o
**com backup antes**, nunca direto:

```bash
# como o dono do n8n (apos a migracao, hako-n8n; antes, lucas):
export HOME=/srv/hako-n8n N8N_USER_FOLDER=/srv/hako-n8n
n8n export:workflow --all --output=/srv/hako-n8n-backups/workflows-$(date -u +%Y%m%dT%H%M%SZ)/
# identifique o id do orfao (o que nao casa com workflows/*.json do repo de produto)
# e apague pela UI (rota segura) ou, com o servico parado e backup feito, via id.
```

Prefira a UI para apagar: ela respeita as invariantes internas do n8n. Só caia no
SQLite com o serviço parado e backup do `database.sqlite` (mais `-wal`/`-shm`) feito.

## Reboot controlado (provar a sobrevivência ao boot)

Tanto a unit de usuário antiga quanto a nova de sistema **nunca passaram por um boot
real** nesta máquina (o último boot registrado era anterior ao processo em pé). A
configuração está provada; o comportamento não. Depois da migração, agende um reboot
controlado e confirme:

```bash
sudo systemctl is-enabled hako-n8n     # enabled
sudo reboot
# apos voltar:
systemctl is-active hako-n8n           # active, sem login interativo
ss -ltnp | grep 5678
```

## Riscos conhecidos

1. **Serviço crítico preso a uma conta humana** (ver acima).
2. **Colisão de porta do task broker** com a CLI (ver acima).
3. **O Node do n8n é uma instalação manual, sem gestor de pacotes.**
   `~lucas/.local/node` (v22.23.1) não tem origem registrada nem caminho de
   atualização definido. É **separado** do Node do sistema
   (`/usr/bin/node`, v24.18.0, pacote `nodejs` do NodeSource), que é o usado pelo
   renderer de protótipos — então um upgrade feito para o HyperFrames **não**
   toca no interpretador do n8n. Os dois envelhecem de forma independente, e só
   um deles tem procedência.
