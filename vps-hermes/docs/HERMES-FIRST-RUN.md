# Primeira ambientação do Hermes

Este documento é o roteiro de apresentação do laboratório ao Hermes. Ele evita uma conversa
inicial gigantesca: fatos estáveis ficam em arquivos curtos e o contexto de cada projeto é
carregado somente quando o trabalho exigir.

## O que já existe

- Hermes instalado nativamente como usuário `hermes`, sem sudo e sem login SSH;
- administrador humano `lucas`, com SSH por chave e sudo;
- workspace compartilhado com o agente em `/srv/hermes-work`;
- painel local em `127.0.0.1:9119`, acessado por túnel SSH;
- backup Restic criptografado no Google Drive;
- auditd e AIDE ativos.

O Hermes oferece mecanismos próprios para personalidade (`SOUL.md`), memória, skills,
sessões e contexto de projeto. Não substitua esses arquivos às cegas. A ambientação deste
repositório cria apenas um `AGENTS.md` operacional no workspace e modelos por projeto.

## Primeiro diálogo recomendado

Depois de instalar o showcase, diga ao Hermes:

> Leia `/srv/hermes-work/AGENTS.md`. Faça somente uma inspeção de leitura dos projetos,
> resuma em até 12 linhas o que pode fazer sozinho e o que precisa de aprovação. Não instale
> pacotes e não altere infraestrutura. Em seguida, verifique os dois projetos showcase e
> apresente os comandos de teste.

Depois:

> Trabalhe apenas em `/srv/hermes-work/projects/showcase-native`. Leia o `AGENTS.md` mais
> próximo, execute os testes e proponha uma melhoria pequena em uma branch Git. Não faça
> deploy até eu aprovar.

Esse fluxo mede entendimento e autonomia sem despejar toda a história da VPS no prompt.

## Política de contexto e tokens

1. Ler primeiro o `AGENTS.md` do workspace e o do projeto atual.
2. Não varrer outros projetos sem necessidade explícita.
3. Consultar runbooks apenas para deploy, domínio, backup ou incidente.
4. Resumir resultados; anexar logs extensos em arquivo e citar o caminho.
5. Usar `/usage` para observar consumo e `/compress` quando a sessão acumular contexto.
6. Abrir uma sessão nova ao mudar de projeto ou objetivo grande.
7. Registrar aprendizado reutilizável como skill/memória somente depois de confirmado.

## Modelo multi-projeto

```text
/srv/hermes-work/
├── AGENTS.md
├── projects/
│   ├── showcase-native/
│   ├── showcase-container/
│   └── <projeto-real>/
└── runbooks/
    ├── deploy.md
    └── domains.md
```

Aplicações escutam somente em `127.0.0.1` numa porta própria. Caddy será a única entrada
pública HTTP/HTTPS quando houver domínios reais. Código e histórico ficam no GitHub; segredos
ficam apenas no host, fora do repositório.

## Critérios para considerar a ambientação aprovada

- Hermes identifica corretamente que não possui sudo;
- consegue editar e testar um projeto sem tocar nos demais;
- o projeto nativo reinicia como serviço de usuário;
- o projeto em contêiner usa Docker rootless e não `/var/run/docker.sock`;
- nenhum serviço de aplicação é exposto publicamente sem proxy;
- commit, teste, deploy e rollback são relatados separadamente;
- reinicialização, backup e restauração são testados.

## Fontes oficiais acompanhadas

- Hermes Agent: https://github.com/NousResearch/hermes-agent
- Docker rootless: https://docs.docker.com/engine/security/rootless/
- Segurança do Docker Engine: https://docs.docker.com/engine/security/
- Credenciais GitHub para servidores: https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys
- Caddy reverse proxy: https://caddyserver.com/docs/caddyfile/directives/reverse_proxy

