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
