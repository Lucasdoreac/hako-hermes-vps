# VPS Ubuntu + Hermes Agent (instalação nativa)

Pacote idempotente para preparar uma VPS Ubuntu 22.04/24.04 sem Docker. O Hermes roda como
usuário não privilegiado e não recebe `sudo`.

> Esta implementação prioriza separação de privilégios. Ela **não** dá root irrestrito ao
> Hermes. Veja [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) para a diferença em relação ao
> requisito original e as opções de autonomia.

## Ordem segura

1. Copie esta pasta para a VPS sem incluir segredos.
2. Entre inicialmente como `root` e execute:

   ```bash
   sudo bash scripts/00-preflight.sh
   sudo ADMIN_USER=lucas ADMIN_SSH_PUBLIC_KEY='ssh-ed25519 AAAA...' bash scripts/10-bootstrap-host.sh
   ```

3. **Abra uma segunda sessão SSH** e confirme que `lucas` entra por chave e consegue usar
   `sudo`. Não feche a sessão root original antes desse teste.
4. Somente depois do teste:

   ```bash
   sudo ADMIN_USER=lucas bash scripts/20-harden-ssh.sh
   sudo bash scripts/30-install-hermes.sh
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
- integridade: AIDE (inicialização manual após instalação);
- logs persistentes e rotação: journald/logrotate;
- backup local rotativo: script `hermes-backup` + timer systemd;
- swap comprimida: zram quando disponível;
- verificação básica: `scripts/90-verify.sh`.

Backups locais **não substituem** cópias externas. Uma segunda etapa deve enviar backups
criptografados para outro provedor/objeto de armazenamento.

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
