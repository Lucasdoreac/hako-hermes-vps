# Isolamento de recursos para inferência local

> Status: adotado. Última revisão: 22/07/2026.

Este documento cobre **uma** pergunta: se um modelo local for instalado neste host, como
impedir que ele derrube o resto.

Ele **não** declara a capacidade da máquina nem quais modelos cabem nela. Esses fatos vivem no
repositório de produto, em
[`docs/RUNTIME-CAPACITY-AND-MODEL-BOUNDARIES.md`](https://github.com/Lucasdoreac/hako-creative-intelligence/blob/main/docs/RUNTIME-CAPACITY-AND-MODEL-BOUNDARIES.md),
e é lá que devem ser atualizados depois de qualquer troca de plano, migração ou resize. Duas cópias dos mesmos
números em dois repositórios públicos divergem no primeiro resize, e ninguém descobre qual das
duas envelheceu.

## Por que existe

O host roda o gateway do Hermes, o PostgreSQL, a API e os workers do HAKO Creative. Um modelo
local é **opcional**; o plano de controle não é. A regra que organiza todas as demais: um
processo opcional não pode desestabilizar um processo obrigatório.

## Regras

- **Separar o serviço do modelo** do PostgreSQL e do gateway — processos distintos, units
  distintas.
- **Aplicar controles de memória e CPU no systemd** (`MemoryMax`, `CPUQuota`) **depois** de medir
  a linha de base. Limite chutado antes da medição ou não segura nada, ou mata o serviço no
  primeiro pico legítimo.
- **Não expor o endpoint do modelo publicamente**: bind em loopback ou rede privada.
- **Reservar RAM** para o sistema operacional, o gateway, o banco e os workers antes de decidir
  quanto sobra para o modelo.
- **Evitar pressão contínua de swap.** Swap ativo durante inferência não é otimização, é aviso.
- **Começar com uma requisição de inferência por vez.** Concorrência entra depois de medida, não
  por padrão.
- **Não habilitar janelas de contexto grandes por padrão** — o cache KV consome memória
  proporcional ao contexto e à concorrência, e pode esgotar a RAM antes do peso do modelo.
- **Benchmarkar antes** de colocar o modelo em qualquer caminho crítico.

## O que este documento não garante

Nenhuma destas regras está verificada por script hoje. São critérios para revisão humana no
momento de instalar um modelo local — não há inferência local rodando neste host, e por isso
nenhuma delas foi exercitada na prática.
