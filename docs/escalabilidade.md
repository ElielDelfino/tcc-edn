# Escalabilidade da solução — Contador de Acessos


**Status:** Arquitetura **projetada**, ainda não implantada. Os números deste documento são os limites
padrão dos serviços AWS (cotas por conta e por região), **não resultados medidos**.

---

## 1. Arquitetura considerada

| Elemento | Decisão documentada |
|---|---|
| API | Amazon API Gateway **REST API** |
| Rotas | `POST /count` incrementa · `GET /count` apenas consulta |
| Processamento | AWS Lambda (Python ou TypeScript, a definir), invocação **síncrona** |
| Banco | DynamoDB `AccessCounter`, partition key `id` = `"hits"`, atributo `count` (Number) |
| Capacidade do banco | `PAY_PER_REQUEST` (on-demand) |
| Incremento | `UpdateItem` atômico (+1) com `ReturnValues=UPDATED_NEW` |
| Consulta | `GetItem`, sem alterar o total |

---

## 2. Como cada serviço escala

| Serviço | Como escala | Limite padrão | Pode aumentar? | Se passar do limite |
|---|---|---|---|---|
| **API Gateway (REST API)** | Gerenciado pela AWS, escala sozinho. | 10.000 req/s por conta/região, com rajada de até 5.000 requisições (algumas regiões novas têm 2.500 req/s) | Sim, a taxa (Service Quotas). A rajada não. | **HTTP 429 – Too Many Requests** |
| **AWS Lambda** | Cada requisição simultânea usa um ambiente de execução; a AWS cria novos conforme a demanda. | 1.000 execuções simultâneas por conta/região (contas novas podem começar com menos). Cada função cresce até **1.000 novos ambientes a cada 10 s**. | Sim, a concorrência da conta | A invocação é recusada (throttling) e o cliente recebe erro |
| **DynamoDB on-demand** | Sem capacidade provisionada; acompanha o tráfego e cobra por requisição. Acomoda na hora até o **dobro do pico anterior**. | Por tabela: 40.000 unidades de leitura e 40.000 de escrita por segundo. **Por partição: 1.000 escritas/s e 3.000 unidades de leitura/s.** | Tabela: sim. **Partição: não.** | Throttling (erro de capacidade excedida) |

**O DynamoDB on-demand não tem capacidade irrestrita.** A tabela escala, mas cada partição tem teto fixo.
Como `POST /count` e `GET /count` acessam sempre o mesmo item (`id = "hits"`), esse teto vale para a
solução inteira — é a chamada **hot key** (chave quente).

**Uma ou duas funções Lambda?** O repositório ainda não define. A taxa de crescimento (1.000 ambientes a
cada 10 s) é **por função**; a cota de concorrência é **compartilhada pela conta**. Separar POST e GET em
duas funções deixa cada uma crescer de forma independente, mas não aumenta o total disponível.

### Por que ser serverless importa neste caso

O cliente não sabe se terá 10 ou 1 milhão de acessos. Com servidores (EC2, por exemplo), a equipe teria
que escolher um tamanho antes: pequeno demais cai no pico, grande demais paga por capacidade parada. Nos
três serviços escolhidos não há servidor para dimensionar: a capacidade acompanha as requisições e a
cobrança é por uso. Com zero acessos, o custo de processamento fica praticamente zero (RNF-01 e RNF-02).

---

## 3. Onde está o gargalo

Toda requisição passa por API Gateway → Lambda → DynamoDB. A capacidade é a do elo mais fraco.

| Etapa | `POST /count` (incrementar) | `GET /count` (consultar) |
|---|---|---|
| API Gateway | ~10.000 req/s (POST + GET somados) | idem |
| Lambda | ~10.000 req/s (limite de 10× a concorrência) | idem |
| DynamoDB, item `hits` | **~1.000 incrementos/s** (1 unidade de escrita por `UpdateItem` em item < 1 KB) | ~6.000 leituras/s com leitura eventualmente consistente; ~3.000/s com leitura fortemente consistente |

**Gargalo:** as escritas no item `hits`, com cerca de **1.000 incrementos por segundo** (≈ 3,6 milhões
por hora).

**Atende o cliente?** O case fala em "10 ou 1 milhão de acessos". Mesmo com 1 milhão de acessos
**concentrados em uma única hora**, a média seria ~280 incrementos/s, menos de 30% do limite. O gargalo
só aparece em picos extremos e concentrados no mesmo segundo. Isso é uma estimativa teórica; a capacidade
real precisa ser confirmada com testes.

**Dica de desenho:** como o `POST` já devolve o novo `count` (`ReturnValues=UPDATED_NEW`), a página não
precisa chamar o `GET` logo depois de registrar o acesso. Isso reduz pela metade as chamadas por visita.

### 3.1 O que acontece com 10× e 100× mais usuários

O `checklist-entrega.md` pede essa resposta. Cálculo considerando só `POST /count` e duração estimada de
~50 ms por execução da Lambda (valor a medir). Concorrência necessária = requisições/s × duração.

| Cenário | Req/s | API Gateway (10.000/s) | Lambda (1.000 simultâneas) | Item `hits` (1.000 escritas/s) | O que fazer |
|---|---|---|---|---|---|
| 1 milhão/mês, espalhado | ~0,4 | Folga total | ~1 execução | Folga total | Nada |
| 1 milhão em 1 dia | ~12 | Folga total | ~1 execução | ~1% | Nada |
| 1 milhão em 1 hora (pico do lançamento) | ~280 | ~3% | ~14 | ~28% | Nada; monitorar |
| **10×** o pico | ~2.800 | ~28% | ~140 | **~280% → throttling** | Write sharding (mínimo 3 fragmentos; 10 dá folga) |
| **100×** o pico | ~28.000 | **~280% → 429** | **~1.400, acima da cota** | **~2.800%** | Pedir aumento de cotas do API Gateway e da Lambda + sharding com 30+ fragmentos + cache no `GET` |

**Leitura da tabela:** o desenho atual atende o volume do case com folga. Em 10×, o primeiro limite a
estourar é o item `hits`. Em 100×, todos os limites padrão estouram e é preciso pedir aumento de cotas
(a cota da tabela, de 40.000 escritas/s, ainda comporta). Nenhum cenário exige trocar os serviços.

---

## 4. O que acontece num pico de acesso (cenário teórico)

Exemplo: o link viraliza e chegam **5.000 `POST /count` por segundo** de repente.

1. **API Gateway** recebe tudo — abaixo de 10.000 req/s.
2. **Lambda** cria novos ambientes. Supondo execuções de ~50 ms (valor a medir), 5.000 req/s precisam de
   ~250 execuções simultâneas, bem abaixo de 1.000. As primeiras requisições podem ter mais latência
   (*cold start*).
3. **DynamoDB** recebe 5.000 incrementos/s no mesmo item — **5× acima do limite da partição**. Parte das
   escritas sofre throttling.

**Sobre novas tentativas (retry) — cuidado para não afirmar errado:**
- O **SDK da AWS dentro da Lambda** faz algumas novas tentativas automáticas quando o DynamoDB responde
  com throttling. Se todas falharem, o código recebe o erro.
- A **invocação síncrona** feita pelo API Gateway **não** é repetida automaticamente se a Lambda falhar.
  O erro volta para o cliente. As duas novas tentativas automáticas da Lambda valem só para invocação
  assíncrona, que não é o nosso caso.
- Por isso a Lambda deve tratar o erro e devolver um status claro (ex.: 429 ou 503), em vez de um 200
  enganoso (RF-06).
- Se o cliente repetir um `POST` que deu *timeout*, o acesso pode ser **contado duas vezes**. O incremento
  é atômico, mas não é idempotente. Para um contador de interesse isso é aceitável; deduplicação exigiria
  identificar cada evento.

---

## 5. Como evitar o gargalo

**Já previsto no desenho atual (MVP):**

| Medida | Efeito |
|---|---|
| `UpdateItem` atômico com `ADD` | Incrementos simultâneos não se sobrescrevem (RNF-04) |
| DynamoDB on-demand | Não é preciso prever capacidade; cobra por uso (RNF-02) |
| `POST` devolvendo o novo `count` | Menos chamadas por visita |

**Propostas de evolução (não implementadas — para o slide "Evolução e Visão de Futuro"):**

| Mitigação | Como funciona | Ganho | Custo / desvantagem |
|---|---|---|---|
| **Write sharding** | Trocar o item único por N itens (`hits#0` … `hits#9`). O `POST` soma +1 num item sorteado; o `GET` lê os N e soma. | 10 fragmentos ≈ 10.000 incrementos/s | **Muda o modelo de dados documentado** (`id = "hits"`); leitura N vezes maior; código mais complexo |
| **Cache no `GET /count`** | Cache de estágio da REST API (ou CloudFront) por alguns segundos. | Leituras quase não chegam à Lambda e ao DynamoDB | O total exibido atrasa alguns segundos; o cache do API Gateway tem cobrança por hora |
| **Throttling no estágio/método da REST API** | Definir limite de req/s para `POST /count`. | Protege contra robôs inflando o contador e contra gasto inesperado | Usuários legítimos podem receber 429 em pico extremo |
| **Concorrência reservada na Lambda** | Fixar o máximo de execuções simultâneas da função. | Limita custo e protege a cota da conta | Requisições acima do limite são recusadas |
| **Aumento de cotas** | Pedir aumento da taxa do API Gateway e da concorrência da Lambda. | Mais capacidade nas duas primeiras etapas | Não resolve o limite por partição do DynamoDB |

---

## 6. Monitoramento (planejado para a Sprint 3)

Ainda não implantado. Métricas que comprovam o comportamento de escala:

| Serviço | Métricas | Alarme sugerido |
|---|---|---|
| API Gateway | `Count`, `4XXError`, `5XXError`, `Latency` | 4XX acima do normal (sinal de 429) |
| Lambda | `ConcurrentExecutions`, `Throttles`, `Errors`, `Duration` | `Throttles` > 0 |
| DynamoDB | `ConsumedWriteCapacityUnits`, `WriteThrottleEvents`, `ThrottledRequests` | `WriteThrottleEvents` > 0 |

O **CloudWatch Contributor Insights** para DynamoDB mostra as chaves mais acessadas e pode provar que
`hits` é a chave quente.

---

## 7. Como validar (quando a stack estiver implantada)

Atende o critério de RNF-01 ("testes com aumento gradual de chamadas") e RNF-04 (chamadas simultâneas).

1. Anotar o `count` inicial com `GET /count`.
2. Enviar um número conhecido de `POST /count` (ex.: 500), em paralelo. O **Collection Runner do Postman**
   faz isso sem terminal.
3. Conferir com `GET /count` se o total aumentou exatamente 500 (prova a atomicidade).
4. Aumentar a carga aos poucos e observar no CloudWatch `Duration`, `Throttles` e `Latency`.
5. Registrar a duração média real da Lambda e substituir o valor estimado de ~50 ms na seção 4.

---

## 8. Respostas prontas para a banca

**"Como a solução suporta mais usuários?"**
Os três serviços são serverless e escalam sozinhos dentro das cotas da AWS, sem servidores para gerenciar.
Pagamos pelo uso.

**"Existe algum gargalo?"**
Sim: todas as escritas vão para o mesmo item `hits`, que aceita cerca de 1.000 incrementos por segundo.
Para o volume do case isso sobra; se precisar de mais, a evolução é write sharding.

**"O que acontece em um pico de acesso?"**
API Gateway e Lambda absorvem o pico. Se o item passar de 1.000 escritas/s, o DynamoDB aplica throttling;
o SDK tenta de novo algumas vezes e, se não conseguir, a Lambda devolve um erro claro. O API Gateway não
repete a chamada sozinho.

**"Como atenderia dez vezes mais usuários?"**
Em 10× o pico de lançamento, só o item `hits` estoura. Resolvemos com write sharding (10 fragmentos),
cache no `GET /count` e alarmes no CloudWatch. API Gateway e Lambda ainda têm folga.

**"E cem vezes mais?"**
Aí todos os limites padrão estouram. Pedimos aumento das cotas do API Gateway e da Lambda no Service
Quotas e aumentamos o número de fragmentos. A arquitetura continua a mesma.

---

## 9. Versão curta para o slide "Escalabilidade"

- **API Gateway (REST):** gerenciado, 10 mil req/s por padrão (ajustável)
- **Lambda:** escala sozinha, +1.000 execuções a cada 10 s, cota de 1.000 simultâneas (ajustável)
- **DynamoDB on-demand:** acompanha o tráfego e cobra por uso, mas cada item aceita ~1.000 escritas/s
- **Gargalo:** item `hits` (~1.000 incrementos/s ≈ 3,6 mi/hora), suficiente para o case
- **Para 10×:** write sharding + cache no GET + alarmes (evolução futura)

---

## 10. Correção proposta para `docs/arquitetura.md`

A seção "Escalabilidade" de `docs/arquitetura.md` diz que o DynamoDB on-demand é "Virtualmente
ilimitado". Isso contradiz a documentação da AWS e a revisão técnica. Sugestão de substituição da tabela:

| Serviço | Como escala | Limite prático |
|---------|------------|---------------|
| API Gateway | Automático (gerenciado) | 10.000 req/s por conta/região (aumentável) |
| Lambda | Concorrência automática, +1.000 ambientes a cada 10 s por função | 1.000 execuções simultâneas (padrão, aumentável) |
| DynamoDB (On-Demand) | Automático, até o dobro do pico anterior | Tabela: 40.000 escritas/s (aumentável). **Item `hits`: ~1.000 escritas/s (fixo — gargalo)** |

Detalhes em `docs/escalabilidade.md`.

---

## Fontes (documentação oficial AWS)

- Cotas do API Gateway: https://docs.aws.amazon.com/apigateway/latest/developerguide/limits.html
- Throttling em REST API: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-request-throttling.html
- Escalabilidade da Lambda: https://docs.aws.amazon.com/lambda/latest/dg/scaling-behavior.html
- Retry da Lambda: https://docs.aws.amazon.com/lambda/latest/dg/invocation-retries.html
- Chaves de partição no DynamoDB: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-partition-key-design.html
- Throttling no modo on-demand: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/TroubleshootingThrottlingOnDemand.html
- Hot partition: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/throttling-key-range-limit-exceeded-mitigation.html
- Write sharding: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-partition-key-sharding.html
- UpdateItem / ReturnValues: https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_UpdateItem.html
