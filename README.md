# Hermes Agent em VPS Ubuntu

Documentação e scripts para instalar o Hermes Agent nativamente em uma VPS Ubuntu,
com endurecimento de segurança, acesso via Codex e operação sem Docker.

## Onde encontrar cada informação

- **[Guia principal e instalação passo a passo](vps-hermes/README.md)**
- **[Níveis de acesso: isolado, sudo mediado e root irrestrito](vps-hermes/docs/ARCHITECTURE.md)**
- **[O que foi realmente implantado na Contabo](vps-hermes/docs/ACTUAL-DEPLOYMENT.md)**
- **[Scripts reproduzíveis](vps-hermes/scripts/)**

## Decisão principal

O Hermes está instalado diretamente no Ubuntu, mas sem root permanente. Isso permite que a
mesma VPS hospede outros serviços com separação de privilégios. O documento sobre
[níveis de acesso](vps-hermes/docs/ARCHITECTURE.md) explica quando ampliar a autonomia e por
que root irrestrito aumenta significativamente o impacto de erros ou comprometimentos.
