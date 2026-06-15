# ☁️ Automação do Desafio GSP323 - Preparar dados para APIs de ML

Bem-vindos ao repositório de suporte para o laboratório **GSP323**! 
Este script foi criado para automatizar a criação da infraestrutura (BigQuery, Cloud Storage, Dataflow, Dataproc) e a execução das APIs de Machine Learning do Google Cloud de forma totalmente automatizada.

## 📋 Pré-requisitos (O que você precisa anotar)
Antes de rodar o script, olhe para o **painel lateral esquerdo** do seu laboratório no Qwiklabs e anote em um bloco de notas as seguintes informações:
1. **ID do Projeto** (ex: *qwiklabs-gcp-...*)
2. **Nome do Dataset do BigQuery** (ex: *lab_892*)
3. **Nome da Tabela do BigQuery** (ex: *customers_451*)
4. **Nome do Bucket** (ex: *qwiklabs-gcp-...-marking*)
5. **Arquivo da Tarefa 3** (Apenas o nome final. Ex: *task3-gcs-963.result*)
6. **Arquivo da Tarefa 4** (Apenas o nome final. Ex: *task4-cnl-951.result*)
7. **Região** (ex: *us-central1* ou *us-east1*)

## 🚀 Como executar no Cloud Shell

1. Abra o **Cloud Shell** (o terminal preto) no painel do Google Cloud.
2. Copie e cole o comando abaixo no terminal e aperte `ENTER`. Ele fará o download do script, dará as permissões e começará a execução automaticamente:

```bash
curl -LO https://raw.githubusercontent.com/Philippe-C-S-Brito/Resolucao_Desafio_GSP323_Google_Cloud/main/desafio_gsp323.sh
sudo chmod +x desafio_gsp323.sh
./desafio_gsp323.sh
```

3. O script vai pausar e perguntar pelas **7 informações** que você separou no Passo 1. Cole uma a uma e aperte `ENTER`.
4. Aguarde a finalização. Quando a mensagem `✅ SCRIPT FINALIZADO!` aparecer, você já poderá validar as tarefas 2, 3 e 4. 
5. Para a **Tarefa 1**, vá no menu `Dataflow > Jobs` no console e espere o status ficar verde (`Succeeded`) antes de validar.

Bons estudos!

# Guia Explicativo: Perform Foundational Data, ML, and AI Tasks (GSP323)

Bem-vindo(a) ao guia de estudos do laboratório de desafio **Perform Foundational Data, ML, and AI Tasks in Google Cloud**. Este material foi criado para explicar passo a passo o que o script de automação está executando nos bastidores da sua conta do Google Cloud.

Neste desafio, o objetivo principal é testar suas habilidades na ingestão de dados, processamento distribuído e consumo de APIs de Inteligência Artificial do Google.

Abaixo está o detalhamento de cada etapa e serviço utilizado.

---

## ⚙️ Configuração Inicial e Rede

Antes de iniciar as tarefas oficiais, o script prepara o terreno. Ele solicita os dados do seu laboratório (Project ID, nomes de arquivos e buckets) e ajusta as configurações de rede.

* **Seleção de Região e Zona:** Define onde os recursos serão criados geograficamente.
* **Acesso Privado e Firewall:** O script habilita o *Private Google Access* e cria regras de firewall (`allow-internal-dataproc`). Isso é um truque importante para evitar que o cluster do Dataproc (que será criado na Tarefa 2) falhe por falta de comunicação interna na rede padrão do laboratório.

---

## 🚀 Tarefa 1: Pipeline de Dados com Dataflow, BigQuery e Cloud Storage

Nesta etapa, construímos um pipeline de ETL (Extração, Transformação e Carga) simplificado.

### 1. Criando os Repositórios
O script cria um *Dataset* e uma tabela vazia no **BigQuery** (`bq mk`), aplicando um esquema (`lab.schema`) que define as colunas e os tipos de dados (como STRING, BOOLEAN, FLOAT). Em seguida, cria um *Bucket* no **Cloud Storage** (`gsutil mb`) para armazenar arquivos temporários.

### 2. Job do Dataflow
O comando `gcloud dataflow jobs run` inicia o processamento real. 
* **O Template:** Utilizamos um modelo pré-pronto do Google chamado `GCS_Text_to_BigQuery`.
* **A Lógica:** Ele lê um arquivo de texto (CSV) armazenado em um bucket público do laboratório, aplica uma função de transformação em JavaScript (UDF) para limpar os dados, e insere o resultado final diretamente na tabela do BigQuery criada no passo anterior.

---

## 🧠 Tarefa 2: Processamento Distribuído com Dataproc (Apache Spark)

O **Cloud Dataproc** é o serviço do Google para rodar clusters de Apache Hadoop e Spark gerenciados.

### 1. Criação do Cluster
O script provisiona um cluster chamado `cluster-desafio` com uma máquina *Master* e duas máquinas *Workers*. Há um "loop de repetição" (`for i in {1..4}`) implementado aqui. Isso ocorre porque, em laboratórios recém-iniciados, a rede pode demorar a ficar pronta, então o script tenta criar o cluster até 4 vezes caso dê erro.

### 2. Movimentando os Dados para o HDFS
HDFS é o sistema de arquivos distribuído do Hadoop. O script usa o comando SSH (`gcloud compute ssh`) para se conectar ao nó master e copiar um arquivo de texto do Cloud Storage (`gs://spls/gsp323/data.txt`) para dentro do disco do cluster (`/data.txt`).

### 3. Rodando o Job Spark
Enviamos um job do tipo Spark (`gcloud dataproc jobs submit spark`) executando a classe `SparkPageRank`. É um algoritmo clássico de análise de links (o mesmo princípio que o Google usava para ranquear páginas web) rodando de forma distribuída nos *workers*.

---

## 🎙️ Tarefas 3 e 4: Consumo de APIs de Inteligência Artificial

A nuvem não é feita só de infraestrutura; aqui usamos modelos de IA pré-treinados do Google. Primeiro, o script habilita as APIs necessárias e gera uma **API Key** para autenticação.

### Tarefa 3: Cloud Speech-to-Text API
Nesta etapa, convertemos áudio em texto.
* O script cria um arquivo de requisição (`speech_req.json`) apontando para um arquivo de áudio FLAC hospedado no Cloud Storage.
* Usamos o comando `curl` para fazer uma chamada HTTP POST (REST API) para o serviço Speech-to-Text.
* O resultado da transcrição é salvo em um JSON e enviado para o seu *Bucket* pessoal.

### Tarefa 4: Cloud Natural Language API
Aqui, analisamos o significado de um texto.
* O comando `gcloud ml language analyze-entities` é acionado para ler uma frase específica (sobre Odin e a mitologia nórdica).
* A API identifica as "entidades" do texto (como "Odin" sendo uma pessoa, "hat" sendo um objeto, etc).
* O resultado também é salvo em um arquivo JSON e enviado para o seu *Bucket*.

---

## 🎉 Conclusão e Validação

O script finaliza imprimindo uma mensagem de sucesso. 

> **Atenção:** As tarefas de APIs (3 e 4) e do Dataproc (2) costumam ser validadas imediatamente ao fim do script. No entanto, o job do **Dataflow (Tarefa 1)** pode levar de 3 a 5 minutos para processar os dados. Você deve aguardar o status mudar para *Succeeded* no painel do Google Cloud antes de clicar em "Verificar meu progresso" na primeira tarefa.
