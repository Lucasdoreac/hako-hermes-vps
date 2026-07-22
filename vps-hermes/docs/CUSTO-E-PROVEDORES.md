# Custo, provedores e o que dá para fazer com cada um

> Escrito em 22/07/2026 para responder a três perguntas concretas. Preços são de consulta pública
> nesta data, em dólar, e envelhecem — este documento **não** é fonte de preço, é fonte de
> **raciocínio de custo**. Confira a tabela do provedor antes de decidir com base em número.

As três perguntas:

1. O que dá para entregar **só com Codex** (OpenAI), se o mês de teste terminar nele?
2. O que muda mantendo **os dois** (OpenAI + Anthropic), como hoje?
3. Como fica o **capex**?

E uma quarta, que apareceu na conversa e é a mais fácil de responder errado: *"você entende de
geração usando computação local, GPU?"* — resposta na seção 6.

---

## 1. A resposta curta

**A esteira roda sem provedor nenhum; a inteligência do produto ainda não está ligada.** São
duas afirmações separadas, e confundi-las é o erro mais fácil de cometer aqui.

O que está provado, em 22/07/2026, na máquina de produção: o caminho que monta as variações,
gera os previews, renderiza o protótipo e entrega no Telegram roda ponta a ponta **sem chamar
modelo nenhum** — 22 tarefas encadeadas, custo de token igual a zero, nenhuma falha.

O que isso **não** prova: que o resultado seja bom, ou sequer que faça sentido. Custo de token
zero significa, por definição, que **nenhum modelo escolheu nada** naquele vídeo — nem o texto,
nem o ritmo, nem o corte. O conteúdo saiu de um template determinístico preenchido com dados de
teste. O que foi provado é o **encanamento**: que as etapas se encadeiam, que nada se perde no
caminho, que o vídeo chega no chat. É pré-requisito, não é o produto.

Em uma frase: **hoje existe um gerador de variações bem instrumentado, alimentado à mão e
avaliado por ninguém.** As duas pontas do laço comercial — de onde entra evidência e para onde
volta resultado — estão vazias, e isso está levantado em detalhe no repositório de produto.

Para o custo, a consequência é boa e vale dizer com todas as letras: **a conta de modelo ainda
não começou.** O consumo até hoje é próximo de zero e o Veo nunca foi chamado. Os números
adiante são o que vai custar quando ligar, não o que custa hoje.

Modelo entra em três lugares, e só neles:

| Onde | Para quê | Dá para trocar de provedor? |
|---|---|---|
| Conversa → briefing | interpretar linguagem e preencher a estrutura | Sim, é um contrato de entrada/saída |
| Reclamação → nova versão | entender "escurece o fundo" e virar parâmetro | Sim |
| Vídeo final | gerar o vídeo de verdade | **Não** — hoje só o Veo |

As duas primeiras são intercambiáveis: qualquer provedor competente resolve. A terceira não é —
e é a única dependência dura do projeto.

---

## 2. Cenário A — só Codex/OpenAI

**Entrega:** tudo. O produto inteiro continua funcionando.

O que muda é **como o trabalho de engenharia é feito**, não o que o produto faz. Codex escreve
código, abre PR, roda teste. A esteira que existe hoje — branch, verificação automática, revisão,
portão humano antes de subir para produção — não muda de forma, porque ela não é do assistente:
é do GitHub e da VPS.

**Custo:** por token, como qualquer API.

| Modelo (jul/2026) | Entrada / 1M | Saída / 1M |
|---|---|---|
| GPT-5.6 Sol (topo) | US$ 5,00 | US$ 30,00 |
| GPT-5.6 Terra (meio) | US$ 2,50 | US$ 15,00 |
| GPT-5.6 Luna (barato) | US$ 1,00 | US$ 6,00 |

**O que se perde:** nada de funcionalidade. Perde-se a segunda opinião — hoje há dois
assistentes com vieses diferentes olhando o mesmo código, e divergência entre eles tem valor de
revisão.

---

## 3. Cenário B — os dois, como hoje

**Entrega:** o mesmo produto, com engenharia mais rápida em duas frentes específicas: leitura de
código legado grande e investigação de causa-raiz.

| Modelo Anthropic (jul/2026) | Entrada / 1M | Saída / 1M |
|---|---|---|
| Opus 4.8 (topo) | US$ 5,00 | US$ 25,00 |
| Sonnet 5 (meio) | US$ 3,00 | US$ 15,00 |
| Haiku 4.5 (barato) | US$ 1,00 | US$ 5,00 |

**Quem paga:** a camada Anthropic é **custeada pessoalmente pelo operador**, fora do orçamento do
projeto. Ela não aparece em nenhuma fatura da empresa e não está em nenhum contrato.

Se o operador parar de pagar, a esteira continua rodando — pela seção 1, ela não chama modelo. O
que ficaria parado é o trabalho de engenharia com esse assistente, e a camada conversacional
quando existir; essa vai precisar de **algum** provedor, não necessariamente deste. É custo
pessoal com benefício para o projeto, e é assim que deve ser lido.

---

## 4. Capex

**O projeto não tem capex.** Nem um item.

| Item | Tipo | Situação |
|---|---|---|
| VPS (6 vCPU, 12 GB, sem GPU) | opex mensal | já contratada, já em uso |
| APIs de modelo | opex variável | paga por uso, sem mínimo |
| Veo (vídeo) | opex variável | paga por segundo gerado |
| Licenças de software | — | nenhuma; toda a base é aberta |
| Hardware de GPU | seria o único capex | **não comprado, e a seção 6 explica por quê** |

A consequência prática: **não há nada para amortizar e nada para encalhar.** Se o projeto parar,
para-se de pagar. Se dobrar de volume, o custo dobra junto — não há degrau de investimento no
meio.

---

## 5. Veo — a única dependência que não tem substituto

O vídeo final é gerado pelo Veo, do Google. É aqui que está a dependência real, e ela é de
**acesso**, não de dinheiro:

- a assinatura **AI Ultra** que dá acesso ao Veo está com o **patrocinador do projeto**, não com
  o operador;
- assinatura e API são coisas diferentes: a assinatura serve a interface do Google, a API cobra
  por segundo gerado e é o que o produto usa;
- a chave não está no projeto. Nenhum teste de Veo foi feito até hoje por falta desse acesso.

Ordem de grandeza de consulta pública em jul/2026: entre **US$ 0,15 e US$ 0,75 por segundo** de
vídeo, conforme a variante e a resolução. Um vídeo de 10 segundos fica na casa de poucos dólares.
Cobra-se só o que é gerado com sucesso.

**Por que isso importa para o custo:** vídeo é a única coisa cara aqui. Um lote de 10 variações
custa centavos até o momento em que vira vídeo — e aí passa a custar dólares. Daí a arquitetura da
seção 7.

---

## 6. Sobre computação local — GPU, TPU, LPU

A pergunta merece resposta direta: **rodar modelo generativo na nossa máquina não é viável, e a
razão é aritmética, não preferência.**

A VPS tem 6 vCPU compartilhados, 12 GB de RAM e **nenhuma GPU**. O que cabe nela:

| Tamanho de modelo | Nesta máquina |
|---|---|
| 3B–4B quantizado | roda; serve para classificar e rotear |
| 7B–8B quantizado | roda devagar, com contexto curto |
| 14B | experimental, aperta a memória |
| 30B–70B | inviável |
| Geração de vídeo | fora de questão — é o caso mais pesado que existe |

Comprar GPU para isso seria o único capex do projeto, e não se paga: o volume de geração é baixo e
concentrado em rajadas. Hardware parado custa igual; API cobra só o que se usa.

As três siglas, sem mistificação:

- **GPU** (NVIDIA) — o padrão. Boa em tudo, cara, e é o que se compraria se fôssemos rodar local.
- **TPU** (Google) — chip próprio do Google, otimizado para os modelos deles. Não se compra; se
  usa através da API do Google. É o que está por trás do Veo.
- **LPU** (Groq) — chip desenhado só para *responder* rápido, não para treinar. Serve modelos
  abertos a uma fração do preço: de **US$ 0,05 a US$ 0,79 por milhão de tokens**, contra
  US$ 5–30 dos modelos de topo. Uma ordem de grandeza mais barato.

A conclusão de engenharia é a mesma dos três: **não somos donos de computação, somos compradores
de computação — e compramos a mais barata que resolve cada etapa.** É o que a próxima seção faz.

---

## 7. Como economizar de verdade

A economia não vem de escolher o provedor barato. Vem de **quase nunca chamar provedor nenhum**.

O produto é organizado em funil: cada etapa reduz o volume antes que ele chegue na etapa cara.

```
tudo o que entra
   ↓  filtro determinístico — código comum, custo ZERO
o que sobrou
   ↓  modelo barato (Groq/LPU ou tier econômico) — classifica e descarta
o que interessa
   ↓  modelo bom (Opus/GPT-5.6) — só onde julgamento importa
os sobreviventes
   ↓  Veo — só o que vai virar vídeo de verdade
entrega
```

Traduzindo em regra de bolso:

| Etapa | Ferramenta certa | Por quê |
|---|---|---|
| Normalizar, deduplicar, filtrar, contar | código comum | não precisa de inteligência; custa zero |
| Classificar em volume | Groq/LPU ou tier econômico | 10× a 20× mais barato, e suficiente |
| Julgamento criativo, texto final | modelo de topo | é onde a qualidade aparece |
| Vídeo | Veo | não há alternativa |

**O erro caro seria o inverso:** mandar tudo para o modelo de topo e deixá-lo decidir o que
importa. É o padrão de quem trata IA como caixa-preta, e multiplica a conta por dez sem melhorar o
resultado.

Este princípio já é regra escrita do projeto, não intenção: nada gasta token antes das etapas que
de fato precisam de linguagem.

---

## 8. Duas esteiras diferentes, que costumam ser confundidas

Vale separar, porque a confusão entre as duas é o que faz um processo parecer travado:

| | **Esteira de desenvolvimento** | **Esteira de operação** |
|---|---|---|
| Onde vive | GitHub | VPS |
| O que faz | escrever, revisar e aprovar mudança | instalar e rodar a mudança aprovada |
| Quem executa | assistente + revisão humana | automação, com portão humano |
| Depende de qual IA? | da que estiver contratada | **de nenhuma** |

A segunda linha é a que responde à pergunta do início. **Produção não depende de assistente
nenhum.** Trocar de provedor de IA muda quem escreve o código; não muda o que está no ar, nem como
sobe, nem quem autoriza.

O que dá solidez a isso é o que já está montado: nada entra em produção sem passar por revisão,
subir é ato aprovado por pessoa, e a máquina é reconstruível a partir do repositório. Isso vale
independentemente de qual IA — ou nenhuma — estiver ajudando a escrever.

---

## 9. O que este documento não afirma

- **Não é tabela de preço.** Os valores são consulta pública de 22/07/2026 e mudam sem aviso.
- **Não mediu o custo real do projeto**, porque ele ainda não existe: o consumo de modelo até hoje
  é próximo de zero, e o Veo nunca foi chamado.
- **Não afirma que o produto esteja pronto.** O que roda hoje é a esteira. A camada que entende
  linguagem e escolhe o que fazer não está ligada, e é ela que vai gerar o custo descrito aqui.
  Quem ler a seção 1 como "está funcionando" leu o encanamento como se fosse o produto.
- **Não compara qualidade** entre os provedores por benchmark próprio. A distinção prática entre
  eles, para este projeto, é preço e disponibilidade — não capacidade.
- **Não recomenda trocar nada.** Descreve o que cada cenário permite e o que custa.
