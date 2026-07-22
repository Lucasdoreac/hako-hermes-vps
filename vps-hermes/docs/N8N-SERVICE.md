# n8n na VPS — serviço, persistência e operação

O n8n orquestra o produto HAKO Creative e roda **no mesmo host**, em loopback. Este
documento registra como ele está provisionado hoje, porque até 22/07/2026 essa
configuração existia **apenas na máquina** — reprovisionar a VPS não a reconstruía.

## Como roda

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

## Decisão em aberto: dono do serviço

Hoje o n8n depende da conta humana `lucas`. Se ela for removida, perder o linger ou
tiver o `~/.local/node` alterado, o serviço cai. Isso contrasta com o runtime HAKO,
que roda em units de sistema sob `hako-creative` (`nologin`), conforme ADR-001 do
repositório de produto.

Migrar para um usuário técnico dedicado é o alinhamento natural — **mas não é
trivial e não deve ser feito às pressas**: o `N8N_ENCRYPTION_KEY` precisa migrar
junto com o `~/.n8n`, senão todas as credenciais do cofre viram lixo cifrado e
precisam ser recriadas à mão.

A decisão fica registrada como aberta, sem recomendação de prazo.

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
