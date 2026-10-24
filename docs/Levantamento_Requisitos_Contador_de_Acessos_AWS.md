# Projeto TCC AWS --- Contador de Acessos

**Tema:** Case Cloud 1 --- Contador de Acessos\
**Contexto:** Startup de marketing lançando uma campanha para um novo
produto\
**Objetivo:** organizar o entendimento do cliente, levantar requisitos
funcionais e não funcionais e mapear esses requisitos para serviços AWS.

> **Nota de escopo:** o case especifica Amazon API Gateway, AWS Lambda e
> Amazon DynamoDB e destaca permissões IAM e chave de partição. Os
> requisitos complementares abaixo são propostas derivadas para tornar a
> solução testável; o grupo deve validá-los e ajustar o escopo final.

## 1. Entendimento do problema

### 1.1 Quem é o cliente?

O cliente é uma startup de marketing que está lançando uma campanha para
divulgar um novo produto. Para despertar interesse antes do lançamento,
publicou uma página do tipo **"Em Breve"** e precisa exibir um contador
com o total de acessos/interações registrados.

O volume é incerto: a página pode receber desde poucas dezenas até
aproximadamente um milhão de acessos. O cliente procura uma solução
simples, de baixo custo, sem gerenciamento de servidores e capaz de se
adaptar à variação da demanda.

### 1.2 Qual problema o cliente possui?

A startup precisa contabilizar os acessos à página da campanha e
apresentar o total atualizado de forma confiável. Uma infraestrutura
dimensionada para volume fixo pode ficar cara quando a demanda for baixa
ou não suportar picos. O desafio é criar um contador **serverless** que
registre os eventos, atualize o total armazenado e permita
consultá-lo/exibi-lo, evitando administrar servidores.

### 1.3 Desafios que precisam ser resolvidos

1.  **Registrar cada acesso:** receber a chamada feita pela página e
    processá-la de forma consistente.
2.  **Atualizar o contador:** incrementar o total sem perder
    atualizações quando várias chamadas ocorrerem próximas umas das
    outras.
3.  **Suportar variação de tráfego:** lidar com crescimento ou picos sem
    provisionar servidores manualmente.
4.  **Manter baixo custo:** evitar recursos permanentemente ligados
    quando não houver demanda e acompanhar os custos.
5.  **Configurar permissões corretamente:** permitir que a função Lambda
    acesse somente os recursos e as operações necessárias no DynamoDB.
6.  **Definir a chave da tabela:** utilizar uma chave de partição
    estável para o registro do contador, por exemplo `id = "hits"`,
    conforme sugere o case.
7.  **Entregar um resultado consultável:** disponibilizar uma resposta
    que a página possa usar para apresentar o total.
8.  **Validar o funcionamento:** demonstrar chamadas à API, atualização
    do valor no DynamoDB e tratamento de erros.

### 1.4 Quais impactos o problema gera?

**Impactos para o negócio** - A equipe de marketing pode não conseguir
medir de forma simples o interesse inicial pelo produto. - Um contador
indisponível ou inconsistente pode reduzir a confiança na informação
apresentada. - Uma solução superdimensionada pode consumir orçamento sem
necessidade; uma solução subdimensionada pode falhar durante a campanha.

**Impactos operacionais e técnicos** - Sem automação de escala, picos de
acesso podem exigir intervenção manual. - Permissões incorretas entre
serviços podem impedir a atualização do contador. - Atualizações
concorrentes mal implementadas podem produzir resultados incorretos. - A
ausência de monitoramento e de estratégia de recuperação pode dificultar
a identificação e a correção de falhas.

**Resultado esperado:** um contador simples, confiável e de baixo
esforço operacional, que acompanhe a demanda da campanha e ofereça ao
cliente uma métrica visível de interesse.

## 2. Visão geral da solução proposta

**Fluxo principal:** Visitante acessa a página → página chama Amazon API
Gateway → API Gateway invoca AWS Lambda → Lambda atualiza/consulta
Amazon DynamoDB → API retorna o resultado à página.

-   **Amazon API Gateway:** expõe o endpoint HTTP que recebe as chamadas
    da página.
-   **AWS Lambda:** executa a lógica do contador sob demanda, sem
    necessidade de administrar servidores.
-   **Amazon DynamoDB:** armazena o registro do contador e seu valor
    acumulado.
-   **AWS IAM:** controla as permissões da função para acessar a tabela.
-   **Amazon CloudWatch (proposta do grupo):** permite acompanhar logs,
    métricas e erros durante testes e execução.

O case especifica API Gateway, Lambda e DynamoDB, além de destacar IAM e
a chave de partição. CloudWatch é recomendado como complemento de
observabilidade; sua inclusão deve ser confirmada no escopo final.

### 2.1 Observação importante sobre a contagem

O grupo deve definir o que significa "acesso". Para a versão inicial,
recomenda-se considerar cada chamada válida ao endpoint como um acesso
contabilizado. Isso **não equivale necessariamente a visitantes
únicos**: recarregamentos da página, robôs e chamadas repetidas podem
aumentar o total. Se o cliente desejar visitantes únicos, será
necessário definir uma estratégia adicional de identificação,
privacidade e deduplicação.

O incremento deve ser implementado de forma atômica no DynamoDB (por
exemplo, usando uma operação de atualização com incremento), para
reduzir o risco de perder incrementos quando houver chamadas
simultâneas. A operação exata deve ser validada durante a implementação.

## 3. Levantamento de requisitos funcionais (RF)

Requisitos funcionais descrevem **o que a solução deve fazer**. Os itens
RF-01 a RF-06 são requisitos propostos para transformar o cenário em
comportamentos testáveis.

  -----------------------------------------------------------------------
  ID                Requisito         Critério de       Prioridade
                    funcional         aceite sugerido   
  ----------------- ----------------- ----------------- -----------------
  RF-01             Receber           Uma chamada       Alta
                    solicitações de   válida ao         
                    contagem por meio endpoint é        
                    de endpoint HTTP  recebida e        
                    disponibilizado   encaminhada para  
                    pelo Amazon API   processamento.    
                    Gateway.                            

  RF-02             Processar a       A chamada aciona  Alta
                    solicitação por   a função e a      
                    uma função AWS    execução termina  
                    Lambda.           com uma resposta  
                                      definida.         

  RF-03             Incrementar o     Após uma chamada  Alta
                    total de acessos  válida, o valor   
                    armazenado no     persistido        
                    Amazon DynamoDB.  aumenta em uma    
                                      unidade.          

  RF-04             Armazenar o       O registro do     Alta
                    contador em       contador pode ser 
                    registro          localizado pela   
                    identificado por  chave definida na 
                    chave de partição tabela.           
                    estável, como                       
                    `id = "hits"`.                      

  RF-05             Retornar o total  A resposta da API Alta
                    atualizado ou     contém o          
                    disponibilizar    resultado         
                    resposta que      esperado em       
                    permita à página  formato acordado, 
                    exibi-lo.         por exemplo JSON. 

  RF-06             Tratar            A API não retorna Média
                    solicitações      sucesso enganoso  
                    inválidas ou      quando ocorre     
                    falhas de         falha; o erro     
                    processamento com fica              
                    resposta de erro  identificável nos 
                    apropriada.       logs.             
  -----------------------------------------------------------------------

**Observação:** o case descreve explicitamente a recepção do clique, o
incremento e o armazenamento no DynamoDB. Consulta/exibição do total,
formato da resposta e tratamento de erros foram detalhados como
requisitos propostos para viabilizar a integração com a página e a
demonstração.

## 4. Levantamento de requisitos não funcionais (RNF)

Requisitos não funcionais descrevem **como a solução deve operar**.
Alguns decorrem diretamente do case --- serverless, baixo custo e
escalabilidade automática --- e outros são propostas de boas práticas a
validar com o grupo.

  -----------------------------------------------------------------------------
  ID                Requisito não          Como               Origem
                    funcional              avaliar/validar    
  ----------------- ---------------------- ------------------ -----------------
  RNF-01            **Escalabilidade:**    Executar testes    Explícito no case
                    acompanhar variação de com aumento        
                    tráfego sem que a      gradual de         
                    equipe gerencie        chamadas e         
                    servidores.            observar erros,    
                                           latência e limites 
                                           dos serviços.      

  RNF-02            **Custo controlado:**  Estimar custos com Explícito no case
                    priorizar cobrança     AWS Pricing        
                    associada ao uso e     Calculator e       
                    evitar infraestrutura  revisar fatores de 
                    ociosa.                cobrança.          

  RNF-03            **Segurança de         Revisar a role IAM Case / boa
                    permissões:** Lambda   e testar           prática
                    deve ter somente       permissões         
                    permissões necessárias autorizadas e      
                    para operar na tabela. negadas.           

  RNF-04            **Consistência:**      Enviar chamadas    Proposta do grupo
                    incrementos            simultâneas e      
                    concorrentes não devem comparar o total   
                    sobrescrever uns aos   final com as       
                    outros.                chamadas válidas   
                                           processadas.       

  RNF-05            **Disponibilidade e    Testar o fluxo     Derivado do
                    resiliência:** reduzir ponta a ponta e    objetivo
                    tarefas operacionais e documentar limites 
                    lidar com variação de  e dependências.    
                    demanda.                                  

  RNF-06            **Observabilidade:**   Conferir logs e    Proposta do grupo
                    falhas e execuções     métricas no        
                    devem ser rastreáveis  CloudWatch;        
                    para facilitar         configurar alarmes 
                    diagnóstico.           se fizerem parte   
                                           do escopo.         

  RNF-07            **Desempenho:** o      Medir latência em  Proposta do grupo
                    endpoint deve          testes             
                    responder em tempo     representativos;   
                    adequado para a        definir o limite   
                    experiência da página. aceitável com      
                                           cliente/grupo.     

  RNF-08            **Manutenibilidade e   Recriar ambiente   Case (IaC) /
                    repetibilidade:**      de teste e         proposta
                    recursos e permissões  verificar se a     
                    documentados e, se     documentação       
                    viável, implantados    corresponde aos    
                    como infraestrutura    recursos.          
                    como código.                              

  RNF-09            **Proteção de dados:** Revisar modelo de  Proposta do grupo
                    armazenar somente os   dados e logs.      
                    dados necessários, sem                    
                    dados pessoais                            
                    desnecessários.                           
  -----------------------------------------------------------------------------

### 4.1 Premissas e limites a declarar

-   A referência a "até um milhão de acessos" é uma possibilidade
    indicada no case, não uma garantia de desempenho já validada.
-   A capacidade real depende da implementação, configurações, cotas dos
    serviços, padrão de chamadas e testes.
-   Uma chave única pode atender ao contador simples, mas deve ser
    avaliada caso exista taxa muito elevada de atualizações
    concorrentes.
-   "Acesso" deve ser definido como chamada válida ao endpoint, salvo
    definição diferente do cliente.
-   Metas numéricas de latência, disponibilidade e tempo de recuperação
    não foram fornecidas nos documentos-base; devem ser definidas pelo
    grupo, se necessárias.

## 5. Mapeamento de requisitos com serviços AWS

  -------------------------------------------------------------------------------
  Requisito         Serviço/recurso   Como atende       Observações de
                    AWS                                 implementação
  ----------------- ----------------- ----------------- -------------------------
  RF-01 --- Receber **Amazon API      Publica o         Definir método e rota;
  chamadas HTTP     Gateway**         endpoint          testar com ferramenta
                                      utilizado pela    HTTP e com a página.
                                      página para       
                                      enviar a          
                                      solicitação.      

  RF-02 ---         **AWS Lambda**    Executa o código  Definir runtime, handler,
  Executar a lógica                   do contador       timeout e tratamento de
                                      quando invocado   exceções.
                                      pela API.         

  RF-03 ---         **Amazon          DynamoDB persiste Preferir atualização
  Incrementar o     DynamoDB + AWS    o valor; Lambda   atômica para evitar perda
  total             Lambda**          executa a         de incrementos.
                                      atualização.      

  RF-04 ---         **Amazon          A chave de        O case sugere
  Identificar o     DynamoDB**        partição localiza `id = "hits"`.
  registro                            o registro único  
                                      do contador.      

  RF-05 ---         **AWS Lambda +    Lambda prepara a  Definir contrato de
  Retornar o        Amazon API        resposta e API    resposta, por exemplo
  resultado         Gateway**         Gateway a entrega `{ "total": 123 }`, como
                                      ao chamador.      proposta.

  RF-06 --- Tratar  **AWS Lambda +    Código/API        CloudWatch é complemento
  falhas            API Gateway +     retornam erros    recomendado, não
                    Amazon            apropriados; logs componente explicitamente
                    CloudWatch**      ajudam a          exigido no case.
                                      investigar.       

  RNF-01 ---        **API Gateway +   Serviços          Validar por testes de
  Escalabilidade    Lambda +          gerenciados       carga e observar
                    DynamoDB**        acompanham        throttling e latência.
                                      variações de      
                                      demanda dentro de 
                                      suas cotas e      
                                      limites.          

  RNF-02 --- Custo  **API Gateway,    Arquitetura evita Estimar com Pricing
  controlado        Lambda e          servidores        Calculator; considerar
                    DynamoDB**        administrados     região, volume, logs e
                                      pela equipe;      capacidade.
                                      custos variam     
                                      conforme uso e    
                                      configuração.     

  RNF-03 ---        **AWS IAM**       Role de execução  O case cita
  Permissões                          da Lambda         `PutItem`/`UpdateItem`;
  mínimas                             autoriza acesso   conceder apenas ações
                                      necessário à      efetivamente usadas e
                                      tabela.           restringir ao ARN da
                                                        tabela.

  RNF-04 ---        **Amazon          Atualizações      Validar concorrência e
  Consistência      DynamoDB**        atômicas ajudam a total final.
                                      preservar         
                                      incrementos       
                                      concorrentes.     

  RNF-05 ---        **API Gateway +   Serviços          Não afirmar
  Resiliência       Lambda +          gerenciados       disponibilidade absoluta;
                    DynamoDB**        reduzem a         documentar limites e
                                      necessidade de    dependências.
                                      administrar       
                                      servidores.       

  RNF-06 ---        **Amazon          Centraliza logs e Definir retenção e
  Observabilidade   CloudWatch**      métricas para     alarmes, se incluídos.
                                      diagnóstico.      

  RNF-07 ---        **API Gateway +   Compõem o caminho Medir latência ponta a
  Desempenho        Lambda +          de requisição e   ponta e ajustar com base
                    DynamoDB**        processamento.    nas evidências.

  RNF-08 ---        **Terraform**     Permite definir e O case sugere CDK; o
  Infraestrutura                      provisionar       instrutor autorizou o uso
  reproduzível                        recursos por      de Terraform pela
                                      código.           familiaridade do grupo.

  RNF-09 ---        **Amazon          O modelo pode     Evitar identificadores
  Minimização de    DynamoDB + lógica armazenar apenas  pessoais desnecessários
  dados             da Lambda**       chave e total,    nos logs.
                                      sem dados         
                                      pessoais.         
  -------------------------------------------------------------------------------

## 6. Resumo da arquitetura e do fluxo de dados

1.  A página "Em Breve" envia uma chamada HTTP ao endpoint.
2.  O Amazon API Gateway recebe a chamada e invoca a função Lambda
    integrada.
3.  A função Lambda valida a solicitação e executa a lógica de
    incremento no DynamoDB.
4.  O DynamoDB atualiza o valor persistido associado à chave do
    contador.
5.  A função prepara a resposta com o total (ou confirmação definida no
    contrato).
6.  O API Gateway devolve a resposta à página, que apresenta o número ao
    visitante.
7.  Logs e métricas podem ser acompanhados no CloudWatch.
8.  A role IAM da Lambda limita o acesso às ações e à tabela
    necessárias.

**Diagrama textual:**

``` text
Visitante
   |
   v
Página "Em Breve"
   | chamada HTTP
   v
Amazon API Gateway
   | invoca
   v
AWS Lambda  ---------> Amazon CloudWatch (logs/métricas - recomendado)
   | atualização/leitura autorizada por IAM
   v
Amazon DynamoDB
   |
   v
Resposta via Lambda e API Gateway
   |
   v
Página exibe o total
```

## 7. Pontos de validação para o grupo

-   [ ] O contador registra toda chamada válida ou somente um tipo
    específico de acesso?
-   [ ] A página precisa receber o total atualizado em cada chamada ou
    haverá endpoint separado de consulta?
-   [ ] Qual formato de resposta será usado pela API?
-   [ ] Qual é a expectativa de latência aceitável?
-   [ ] Quais testes demonstrarão o comportamento com chamadas
    simultâneas?
-   [ ] CloudWatch, alarmes e infraestrutura como código farão parte da
    entrega ou serão melhorias?
-   [ ] Qual estratégia de backup/recuperação será adotada para o
    registro, caso a banca exija esse tópico?
-   [x] A implantação será feita por AWS CDK em Python ou TypeScript?
    **Decisão:** Terraform, com autorização do instrutor (familiaridade
    do grupo e organização do código).

## 8. Critérios de demonstração sugeridos

1.  Mostrar a tabela DynamoDB e o valor inicial do contador.
2.  Fazer uma chamada à API e demonstrar que o valor aumentou em uma
    unidade.
3.  Fazer várias chamadas e conferir o total persistido.
4.  Executar chamadas concorrentes para validar a estratégia de
    incremento.
5.  Demonstrar uma chamada inválida ou uma falha controlada e a resposta
    correspondente.
6.  Mostrar a role IAM da Lambda, evidenciando o acesso restrito à
    tabela.
7.  Mostrar logs/métricas do CloudWatch, se incluídos.
8.  Registrar uma estimativa de custos e explicar quais fatores podem
    alterá-la.

## 9. Referências e base utilizada

-   **Cases_Cloud_Tema 1 --- "1 - Contador de Acessos"**: descreve a
    startup de marketing, a página "Em Breve", a incerteza de volume, o
    objetivo serverless e os serviços API Gateway, Lambda e DynamoDB;
    destaca permissões IAM, chave de partição `id = "hits"` e
    possibilidade de uso do CDK (o grupo adotou Terraform, com autorização
    do instrutor).
-   **Guia do Projeto TCC AWS**: orienta a apresentação do problema,
    levantamento de RF e RNF, visão geral e diagrama da arquitetura,
    justificativa técnica, mapeamento de requisitos, escalabilidade,
    segurança, custos, recuperação e demonstração.

Este documento cobre a etapa solicitada --- entendimento do problema,
requisitos e mapeamento AWS. Ele não substitui a validação do grupo, a
implementação nem as evidências de funcionamento exigidas para a entrega
final.
