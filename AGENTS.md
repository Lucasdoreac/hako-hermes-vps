# Orientações para agentes — infraestrutura HAKO

## Escopo

Este repositório público descreve a VPS, o Hermes nativo e clientes administrativos. O produto
privado fica em `Lucasdoreac/hako-creative-intelligence` e não deve ser copiado para cá.

## Segurança

- Nunca publique chaves privadas, senhas, tokens, `.env`, relatórios com segredos ou backups.
- Não dê sudo ao usuário `hermes` e não execute o Hermes como root.
- Mudanças em SSH devem validar `sshd -t` e manter uma sessão administrativa aberta.
- Não altere firewall, contas, backups ou serviços remotos sem autorização explícita.
- Scripts devem ser idempotentes quando possível e criar rollback antes de mudanças sensíveis.

## Verificação

- Para scripts shell modificados, execute `bash -n <arquivos>`.
- Para PowerShell, valide com o parser antes de publicar.
- Use caminhos configuráveis; configurações locais permanecem ignoradas pelo Git.
- Trabalhe em branch e PR, preservando alterações não relacionadas do usuário.
