# Decisão arquitetural: autonomia do Hermes

## O que o PO aparentemente pediu

- instalação nativa, sem o empacotamento “one-click Docker”;
- acesso direto ao sistema operacional da VPS;
- capacidade de instalar, configurar e operar outros serviços;
- Hermes como administrador principal do servidor.

Docker não elimina acesso root por definição. Ele isola o processo do host. Um container
privilegiado, com o socket Docker ou diretórios do host montados, pode adquirir poder
equivalente a root — frequentemente com uma superfície de ataque pior e menos evidente.

## O que foi implementado

O Hermes foi instalado nativamente, mas roda como o usuário `hermes`, sem senha, login SSH
ou sudo. Ele administra seu workspace, configuração, navegador e gateway, mas não pode
alterar firewall, usuários, pacotes do sistema, systemd global ou dados de outros serviços.

Essa foi uma escolha de segurança deliberada e difere do requisito de “dominar tudo”. O
administrador humano `lucas` continua sendo a fronteira de privilégio.

## Três níveis possíveis

1. **Isolado (implementado e recomendado):** Hermes sem sudo. Serviços adicionais usam
   usuários e unidades systemd próprios. Mudanças no host passam por um administrador.
2. **Elevação mediada:** Hermes recebe comandos sudo específicos e auditáveis em
   `/etc/sudoers.d/hermes`, por exemplo reiniciar uma unidade previamente aprovada. Nunca
   permitir shell, gerenciador de pacotes, edição arbitrária ou curingas amplos.
3. **Root irrestrito:** Hermes pode fazer tudo, inclusive apagar o host, extrair todos os
   segredos, desativar auditoria e comprometer serviços vizinhos. Reproduz melhor a intenção
   literal do PO, mas não é apropriado para uma VPS com múltiplos serviços ou dados reais.

## Recomendação para vários serviços

Manter o nível 1 e criar cada serviço com usuário, diretório, portas e unidade systemd
separados. Quando uma automação recorrente exigir privilégio, promover apenas essa operação
ao nível 2 por meio de um script root-owned, argumentos validados, log e aprovação explícita.

O Hermes pode coordenar deploys via Git e pipelines sem possuir root permanente. Acesso ao
dashboard permanece em `127.0.0.1:9119` e deve ser feito por túnel SSH.
