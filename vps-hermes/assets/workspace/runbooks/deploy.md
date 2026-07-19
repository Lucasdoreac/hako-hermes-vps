# Runbook de deploy

1. Confirme projeto, branch, commit e `AGENTS.md` local.
2. Execute testes e verificações de segurança do projeto.
3. Confirme que segredos estão fora do Git e que a aplicação usa `127.0.0.1`.
4. Descreva mudança, risco, migração e rollback; obtenha aprovação.
5. Faça deploy apenas pelo mecanismo declarado no projeto.
6. Verifique serviço, healthcheck e logs sem imprimir segredos.
7. Registre versão implantada e comando de rollback.

Projetos nativos usam serviço systemd de usuário. Projetos em contêiner usam o contexto
Docker rootless do usuário `hermes`. Configuração de Caddy, DNS, firewall e systemd global é
administrativa e não deve ser improvisada pelo agente.

