# Fronteira Hermes ↔ runtimes HAKO

> Status: proposta para revisão por pares.
>
> Este documento registra a separação entre o agente construtor Hermes e os produtos HAKO executados no mesmo host ou em hosts futuros.

## 1. Princípio

Hermes constrói e mantém. O runtime HAKO executa.

A indisponibilidade do Hermes não deve interromper a rotina de um produto HAKO já implantado.

Compartilhar VPS não implica compartilhar usuário, privilégios, segredos, banco, memória ou identidade operacional.

## 2. O que pertence ao Hermes

- workspace de engenharia;
- inspeção de repositórios;
- criação de branches e Pull Requests;
- execução de testes e validações autorizadas;
- documentação e manutenção;
- memória de fatos estáveis do ambiente de engenharia;
- ferramentas necessárias para construir e diagnosticar sistemas dentro das permissões concedidas.

## 3. O que não pertence ao Hermes

- hot path de atendimento de clientes;
- banco operacional do produto;
- memória conversacional de clientes;
- perfis comerciais ou históricos identificáveis;
- segredos de runtime disponíveis por padrão;
- publicação ou envio de alto impacto sem gate correspondente;
- root permanente;
- dependência obrigatória para que o produto continue funcionando.

Dados reais de clientes não devem ser promovidos para a memória cognitiva do Hermes. Quando uma tarefa de manutenção exigir inspeção de dado real, o acesso deve ser pontual, autorizado, mínimo, auditável e não persistido como memória geral do agente.

## 4. Modelo de implantação

Cada produto HAKO deve possuir, no mínimo:

- usuário de serviço próprio, sem sudo por padrão;
- diretório próprio;
- segredos próprios fora do Git;
- banco/role próprios quando houver persistência;
- portas em loopback até publicação explicitamente aprovada;
- unidade de serviço própria;
- healthcheck;
- observabilidade e rollback definidos;
- dono operacional explícito.

O administrador humano permanece a fronteira de privilégio do host. Elevação mediada pode existir apenas para operações específicas, auditáveis e previamente aprovadas.

## 5. Canais

Os canais de operação do Hermes não definem os canais dos produtos HAKO.

Telegram ou qualquer bridge suportada pelo Hermes serve ao operador/desenvolvedor conforme configuração do agente. Atendimento de produção por WhatsApp deve usar o adapter oficial definido pelo produto — no primeiro caso, Meta/WhatsApp Cloud API em sandbox — e não herdar automaticamente uma bridge de WhatsApp do Hermes.

## 6. Fluxo de alteração

```text
operador
  -> Hermes
  -> repositório correto
  -> branch
  -> testes
  -> Pull Request
  -> revisão/aprovação
  -> CI/CD ou procedimento de deploy autorizado
  -> runtime HAKO
```

O chat não é o mecanismo de deploy. O estado do processo não é prova suficiente de sucesso; healthcheck no boundary correto e alvo de rollback devem ser registrados.

## 7. Relação com `hako-core`

Este repositório não define nem hospeda um `hako-core` de produto.

Infraestrutura compartilhada do Hermes continua separada de primitives de runtime. Um futuro core compartilhado só deve nascer após evidência de reuso em produtos reais ou necessidade de segurança que justifique implementação única.

## 8. Consequência operacional

A fronteira desejada é:

```text
Hermes plane
  constrói / testa / mantém
        |
        | artefatos versionados e mudanças aprovadas
        v
HAKO runtime plane
  serviço isolado / dados próprios / políticas próprias
        |
        v
Channel adapters e APIs externas
```

Essa separação limita blast radius, reduz acoplamento e impede que memória, privilégios e canais do agente construtor se tornem implicitamente parte do produto.