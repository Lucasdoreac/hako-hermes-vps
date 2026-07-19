# VPS Ubuntu + Hermes Agent (instalação nativa)

Pacote idempotente para preparar uma VPS Ubuntu 22.04/24.04 sem Docker. O Hermes roda como
usuário não privilegiado e não recebe `sudo`.

> Esta implementação prioriza separação de privilégios. Ela **não** dá root irrestrito ao
> Hermes. Veja [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) para a diferença em relação ao
> requisito original e as opções de autonomia.

## Comece aqui

Este repositório responde a três perguntas diferentes:

| Quero entender... | Abra este documento |
|---|---|
| O Hermes deveria ter root? Quais são os riscos e níveis de autonomia? | **[Níveis de acesso e decisão arquitetural](docs/ARCHITECTURE.md)** |
| O que foi realmente instalado e o que mudou durante a implantação? | **[Registro da implantação Contabo](docs/ACTUAL-DEPLOYMENT.md)** |
| Como repetir a instalação em outra VPS? | Continue em **[Ordem segura](#ordem-segura)** |
| Como ambientar o Hermes e demonstrar vários projetos? | **[Primeira ambientação e showcase](docs/HERMES-FIRST-RUN.md)** |

### Resumo em linguagem direta

- **Sem Docker:** o Hermes foi instalado diretamente no Ubuntu.
- **Sem root permanente:** ele opera o próprio ambiente, mas não controla todo o servidor.
- **Vários serviços:** a VPS pode hospedar outros sistemas, preferencialmente cada um com
  usuário, diretório e serviço próprios.
- **Mais autonomia:** pode ser concedida por comandos administrativos específicos e
  auditáveis, sem entregar acesso root irrestrito.
- **Root total:** é tecnicamente possível, mas permite também ler todos os segredos,
  desativar proteções e destruir ou comprometer todos os serviços da VPS.

### Mapa rápido da instalação

```text
Internet
   |
   +-- SSH (única porta pública)
          |
          +-- lucas   -> administração do Ubuntu com sudo
          +-- hermes  -> agente sem sudo
                 |
                 +-- workspace: /srv/hermes-work
                 +-- gateway: serviço automático
                 +-- dashboard: 127.0.0.1:9119 via túnel SSH
```

## Ordem segura

1. Copie esta pasta para a VPS sem incluir segredos.
2. Entre inicialmente como `root` e execute:

   ```bash
   sudo bash scripts/00-preflight.sh
   sudo ADMIN_USER=lucas ADMIN_SSH_PUBLIC_KEY='ssh-ed25519 AAAA...' bash scripts/10-bootstrap-host.sh
   ```

3. **Abra uma segunda sessão SSH** e prove que `lucas` entra por chave e consegue usar
   `sudo`. O marcador só é criado por uma elevação real iniciada por esse usuário:

   ```bash
   sudo ADMIN_USER=lucas bash scripts/15-validate-admin.sh
   ```

   Não feche a sessão root original antes desse teste. `sudo -n true` não é usado porque
   esta configuração mantém sudo protegido por senha.
4. Somente depois do teste:

   ```bash
   sudo ADMIN_USER=lucas bash scripts/20-harden-ssh.sh
   curl --proto '=https' --tlsv1.2 -fsSL https://hermes-agent.nousresearch.com/install.sh -o /tmp/hermes-install.sh
   sha256sum /tmp/hermes-install.sh   # revise e aprove conscientemente este valor
   sudo HERMES_INSTALLER_SHA256='<sha256-aprovado>' bash scripts/30-install-hermes.sh
   sudo bash scripts/40-integrity-monitoring.sh
   sudo bash scripts/50-google-drive-backup.sh
   ```

5. Configure o provedor/modelo interativamente como usuário Hermes:

   ```bash
   sudo -iu hermes
   hermes setup --portal        # ou: hermes model
   hermes doctor
   hermes gateway setup         # opcional: Telegram/Discord/etc.
   hermes gateway install
   exit
   sudo loginctl enable-linger hermes
   sudo -iu hermes hermes gateway start
   ```

O gateway de usuário com *linger* inicia no boot e pode ser atualizado/reiniciado sem dar
privilégios root ao agente.

## O que substitui os “premium features”

- firewall: UFW;
- bloqueio de força bruta: Fail2ban;
- atualizações de segurança: unattended-upgrades;
- sincronização de horário: chrony;
- auditoria: auditd;
- integridade: AIDE com baseline e verificação diária;
- logs persistentes e rotação: journald/logrotate;
- backup local rotativo: script `hermes-backup` + timer systemd;
- recuperação externa: Restic criptografado enviado ao Google Drive por rclone;
- swap comprimida: zram quando disponível;
- verificação básica: `scripts/90-verify.sh`.

O backup externo exige autorização Google e uma senha Restic de pelo menos 20 caracteres.
Essa senha deve ser guardada fora da VPS e fora do Drive usado pelo backup; sem ela não há
restauração. O conteúdo enviado ao Drive já sai criptografado da VPS.

O remote usa o escopo `drive.file`: ele acessa somente arquivos criados pelo próprio rclone.
Um limite de quatro operações por segundo reduz erros de cota do cliente público. Para uso
intensivo, configure um Client ID próprio conforme a documentação oficial do rclone.

## Segurança do Hermes

- usuário `hermes` sem senha, login SSH ou sudo;
- `approvals.mode: manual` e cron perigoso negado;
- `HERMES_YOLO_MODE=0`;
- `HERMES_WRITE_SAFE_ROOT=/srv/hermes-work:/home/hermes/.hermes`;
- API em `127.0.0.1`; nenhuma porta do Hermes é aberta no firewall;
- segredos ficam em `/home/hermes/.hermes/.env` com modo `0600` e nunca neste repositório.

Fontes oficiais: https://github.com/NousResearch/hermes-agent e
https://hermes-agent.nousresearch.com/docs/

O estado e as exceções observadas na primeira implantação estão em
[docs/ACTUAL-DEPLOYMENT.md](docs/ACTUAL-DEPLOYMENT.md).
