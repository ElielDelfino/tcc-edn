Slide 1 — Apresentação do projeto | 0:00–0:25
Olá, pessoal!
Somos o G3 e vamos apresentar a vocês o projeto de Contador de Acessos, uma proposta desenvolvida utilizando serviços AWS para criar uma solução capaz de contar acessos de forma escalável, sem a necessidade de administrar servidores.

Slide 2 — O problema | 0:25–1:00
Imagine que uma startup de marketing está prestes a lançar um produto e quer disponibilizar um contador de acessos na página de lançamento.
O desafio está justamente aqui, não sabemos quantas pessoas vão acessar essa página. Podem ser apenas dez, quinhentos ou até um milhão de acessos.
Nesse cenário, manter um servidor ligado o tempo todo pode gerar custos desnecessários, enquanto dimensionar a infraestrutura para um volume fixo pode não atender à demanda do nosso cliente.
Por isso, pensamos em uma solução flexível, econômica e que não exigisse uma equipe dedicada à administração de servidores.

Slide 3 — Requisitos e solução proposta | 1:00–2:15
Para atender a esse desafio, levantamos os principais requisitos funcionais e não funcionais, que orientaram a nossa proposta: uma arquitetura serverless, utilizando três serviços principais da AWS:
• O API Gateway recebe as requisições HTTP; 
• O AWS Lambda processa as chamadas e executa a lógica do contador; 
• E o Amazon DynamoDB armazena o total de acessos, identificado pela chave “hits”.
A cada acesso, a solução deve incrementar o contador e devolver o total atualizado em formato JSON.
Além disso, buscamos atender a requisitos como escalabilidade automática, custo proporcional ao uso, permissões mínimas de acesso e rastreabilidade de falhas pelo CloudWatch.
Desenvolvemos uma infraestrutura definida com Terraform, e utilizamos o GitHub para organizar e compartilhar os arquivos do projeto.
Passo agora a palavra ao Eliel Delfino, que irá apresentar o overview da solução e explicar um pouco mais sobre os serviços escolhidos.

---

## Rogério Augusto Sabino - Slides 13 a 15
Tempo total previsto: 2 minutos e 30 segundos.

### Slide 13 - Recuperação (45 segundos)

Agora vamos entender como nossa solução foi planejada para se recuperar de possíveis falhas.

Trabalhamos com dois caminhos diferentes.

O primeiro é a recuperação da infraestrutura. Com Terraform e GitHub Actions, podemos recriar os recursos da aplicação de forma automatizada. Para esse processo, estimamos de três a seis minutos.

O segundo caminho é a recuperação dos dados. Utilizando o PITR do DynamoDB, quando habilitado, podemos restaurar uma tabela para um momento anterior, dentro de uma janela de até 35 dias. Nesse caso, estimamos de dez a trinta minutos.

Assim, buscamos garantir estratégias independentes para recuperar a infraestrutura e os dados.

### Slide 14 - Diferenciais (55 segundos)

Nosso projeto vai além de simplesmente contar acessos. Buscamos aplicar boas práticas de automação, segurança e monitoramento na nuvem.

Entre os diferenciais estão a infraestrutura como código com Terraform, os testes automatizados e a pipeline de integração contínua pelo GitHub Actions.

Também utilizamos autenticação OIDC, que permite trabalhar com credenciais temporárias da AWS, sem armazenar chaves permanentes no repositório.

O projeto contempla ainda recursos de monitoramento com CloudWatch e alertas, cuja validação na AWS depende da integração final.

Como futuras melhorias, planejamos utilizar CloudFront, AWS WAF, AWS Budgets e X-Ray, além da contagem de visitantes únicos com atenção à LGPD.

Com essas evoluções, buscamos uma aplicação mais segura e preparada para crescer.

### Slide 15 - Conclusão (50 segundos)

Para concluir, nosso desafio foi desenvolver um contador capaz de atender desde poucos visitantes até um milhão de acessos.

Escolhemos uma arquitetura serverless, utilizando API Gateway, Lambda e DynamoDB, sem a necessidade de administrar servidores diretamente.

Também calculamos estimativas de custos para cem, dez mil e um milhão de acessos. No cenário de um milhão, o valor apresentado ficou próximo de quatro dólares por mês, considerando as premissas e cotas gratuitas da simulação.

A solução foi preparada para testes de concorrência e para a recriação da infraestrutura com Terraform. As validações completas na AWS ainda dependem dos testes finais da equipe.

Assim, apresentamos uma solução automatizada, escalável e de baixo custo.

Muito obrigado pela atenção! Ficamos à disposição para perguntas.
