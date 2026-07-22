# Hermes Agent em VPS Ubuntu

Documentação e scripts para instalar o Hermes Agent nativamente em uma VPS Ubuntu,
com endurecimento de segurança, acesso via Codex e operação sem Docker.

Este repositório é o lote de **infraestrutura** do inventário definido em
`Lucasdoreac/hako-creative-intelligence#85`. A classificação abaixo cobre os 12 Markdown da
infra principal (este índice, `vps-hermes/README.md` e os dez arquivos em `vps-hermes/docs/`).
Clientes macOS/Windows e referências internas de skills são documentação de ferramenta e ficam fora
do conjunto de 12 explicitamente medido pela #85.

## Onde encontrar cada informação

- **[Guia principal e instalação passo a passo](vps-hermes/README.md)**
- **[Níveis de acesso: isolado, sudo mediado e root irrestrito](vps-hermes/docs/ARCHITECTURE.md)**
- **[O que foi realmente implantado na Contabo](vps-hermes/docs/ACTUAL-DEPLOYMENT.md)**
- **[Produto de inteligência criativa](https://github.com/Lucasdoreac/hako-creative-intelligence)** — repositório separado
- **[Scripts reproduzíveis](vps-hermes/scripts/)**
- **[Preparação e acesso pelo macOS](clients/macos/README.md)**
- **[Atalhos e auditoria local no Windows](windows/README.md)**

## Inventário classificável da infraestrutura

O critério é o mesmo da #85: `estado` só vale com data + comando de verificação; `decisão` preserva
o porquê ou um runbook normativo; `intenção viva` aponta para issue; `intenção morta` precisa de
marcador histórico; `duplicata` deve ser apagada, não acumulada no índice.

| Documento | Categoria | Evidência / rastreio | Papel |
|---|---|---|---|
| [README.md](README.md) | `decisão` | — | Porta de entrada e fronteira entre host, ferramentas e produto. |
| [vps-hermes/README.md](vps-hermes/README.md) | `estado` | 2026-07-22 · `sudo bash vps-hermes/scripts/90-verify.sh` | Instalação reproduzível e configuração base do host/Hermes. |
| [ACESSO-VPS.md](vps-hermes/docs/ACESSO-VPS.md) | `estado` | 2026-07-22 · `sudo bash vps-hermes/scripts/95-security-audit.sh` | Forma suportada de acesso administrativo e exposição de rede. |
| [N8N-SERVICE.md](vps-hermes/docs/N8N-SERVICE.md) | `estado` | 2026-07-22 · `systemctl status n8n` | Operação do serviço n8n instalado no host. |
| [ARCHITECTURE.md](vps-hermes/docs/ARCHITECTURE.md) | `decisão` | — | Níveis de autonomia, privilégios e risco do Hermes. |
| [ACTUAL-DEPLOYMENT.md](vps-hermes/docs/ACTUAL-DEPLOYMENT.md) | `estado` | 2026-07-22 · `sudo bash vps-hermes/scripts/90-verify.sh` | Registro do que está instalado e das exceções observáveis. |
| [HAKO-CREATIVE-DEPLOY.md](vps-hermes/docs/HAKO-CREATIVE-DEPLOY.md) | `decisão` | — | Contrato/runbook de deploy do produto no host, sem ser fonte do domínio. |
| [HAKO-CREATIVE-RESTART-CLEAN.md](vps-hermes/docs/HAKO-CREATIVE-RESTART-CLEAN.md) | `decisão` | — | Runbook normativo de restart clean e suas condições de segurança/rollback. |
| [ISOLAMENTO-DE-RECURSOS.md](vps-hermes/docs/ISOLAMENTO-DE-RECURSOS.md) | `decisão` | — | Política de isolamento de usuários, recursos e serviços compartilhando VPS. |
| [HAKO-RUNTIME-BOUNDARY.md](vps-hermes/docs/HAKO-RUNTIME-BOUNDARY.md) | `decisão` | — | Fronteira adotada entre Hermes construtor e runtimes HAKO. |
| [HAKO-CICD-DEPLOY.md](vps-hermes/docs/HAKO-CICD-DEPLOY.md) | `estado` | 2026-07-22 · `sudo bash vps-hermes/scripts/90-verify.sh` | Integração versionada de CI/CD com o host. |
| [CUSTO-E-PROVEDORES.md](vps-hermes/docs/CUSTO-E-PROVEDORES.md) | `intenção viva` | `hako-creative-intelligence#64` | Premissas de provedores/custo que precisam acompanhar a decisão de roteamento do produto. |

Não foi identificada duplicata segura para remoção neste lote. Onde há sobreposição, os documentos
tratam fronteiras diferentes (decisão arquitetural, runbook, estado implantado ou operação).

## Decisão principal

O Hermes está instalado diretamente no Ubuntu, mas sem root permanente. Isso permite que a
mesma VPS hospede outros serviços com separação de privilégios. O documento sobre
[níveis de acesso](vps-hermes/docs/ARCHITECTURE.md) explica quando ampliar a autonomia e por
que root irrestrito aumenta significativamente o impacto de erros ou comprometimentos.

## Fronteira com os projetos

Este repositório descreve o host, a segurança e a operação do Hermes. Código de produto,
workflows n8n, contratos de eventos, prompts e decisões comerciais vivem em repositórios
próprios. O primeiro deles é
[`hako-creative-intelligence`](https://github.com/Lucasdoreac/hako-creative-intelligence).
