# Registro da implantação Contabo

Data: 2026-07-18/19

## Estado obtido

- Ubuntu 24.04 LTS, kernel atualizado;
- SSH por chave; login SSH de root e autenticação por senha desativados;
- UFW com somente OpenSSH, Fail2ban, chrony, auditd e unattended-upgrades;
- zram ativo após instalar `linux-modules-extra` correspondente ao kernel;
- Hermes Agent 0.18.2 nativo, usuário `hermes` sem sudo;
- Node.js, Chromium/Playwright, FFmpeg, ripgrep e toolchain nativos;
- OpenAI Codex OAuth; modelo padrão `gpt-5.6-sol`;
- gateway do Hermes como serviço systemd de usuário com linger;
- dashboard em loopback, acessível somente por túnel SSH;
- backup local diário, retenção de sete dias, validado por execução real.

## Diferenças em relação ao procedimento inicial

- Nous Portal foi descartado porque exigia plano próprio; foi usado Codex OAuth.
- O instalador oficial não tinha sudo e pulou dependências do host; elas foram instaladas
  posteriormente pelo administrador.
- O Node gerenciado pelo Hermes precisou ser colocado no `PATH` para o Playwright.
- O zram exigiu o pacote `linux-modules-extra` do kernel após o primeiro reboot.
- O gateway precisou de `loginctl enable-linger hermes` e de uma sessão systemd do usuário.
- O dashboard compilou os assets na primeira inicialização e ficou preso a `127.0.0.1`.

## Correções após auditoria estática

- novas instalações exigem senha sudo válida e uma prova feita numa segunda sessão SSH antes
  de bloquear o login root;
- `/usr/local/bin/hermes` passou a ser um lançador root-owned que recusa execução como root;
- links globais para Node, npm e npx pertencentes ao usuário `hermes` foram removidos;
- root instala apenas pacotes APT declarados; Playwright/Node rodam exclusivamente como
  `hermes`;
- o instalador oficial agora exige SHA-256 explicitamente aprovado.

## Segredos deliberadamente ausentes

Este repositório não contém senhas, tokens OAuth, chaves privadas SSH, códigos de aparelho,
conteúdo de `.env` da VPS ou backups. A autenticação deve ser refeita em cada implantação.
