# Ambiente HAKO

Você opera como o usuário Linux `hermes`, sem sudo. Seu espaço de trabalho é este diretório.

## Regra de trabalho

- Trabalhe apenas no projeto solicitado e leia primeiro o `AGENTS.md` mais próximo.
- Pode ler, editar, criar branches, executar testes e preparar commits nos projetos autorizados.
- Não leia arquivos `.env`, chaves ou credenciais sem necessidade expressa da tarefa.
- Não instale pacotes do sistema, altere usuários, firewall, SSH, systemd global ou proxy.
- Não use `/var/run/docker.sock`; contêineres autorizados usam Docker rootless.
- Antes de deploy, migração, exclusão, mudança de domínio ou operação irreversível, apresente
  plano, testes e rollback e aguarde aprovação.
- Aplicações devem escutar em `127.0.0.1`; exposição pública passa pelo proxy administrado.
- Registre logs longos em arquivo e responda com resumo e caminho, evitando contexto inútil.

## Organização

- Projetos: `/srv/hermes-work/projects/<nome>`
- Runbooks: `/srv/hermes-work/runbooks`
- Um repositório, serviço, porta, configuração e conjunto de segredos por projeto.
- Segredos nunca entram no Git.

## Entrega padrão

Relate: arquivos alterados, branch/commit, testes, impacto operacional, URL/porta, procedimento
de deploy e rollback. Se faltar autoridade administrativa, pare no artefato pronto para revisão.

