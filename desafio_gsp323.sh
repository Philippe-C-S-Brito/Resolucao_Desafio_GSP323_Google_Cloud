#!/bin/bash

# Definição de Cores
BLACK_TEXT=$'\033[0;90m'
RED_TEXT=$'\033[0;91m'
GREEN_TEXT=$'\033[0;92m'
YELLOW_TEXT=$'\033[0;93m'
BLUE_TEXT=$'\033[0;94m'
MAGENTA_TEXT=$'\033[0;95m'
CYAN_TEXT=$'\033[0;96m'
WHITE_TEXT=$'\033[0;97m'

NO_COLOR=$'\033[0m'
RESET_FORMAT=$'\033[0m'

BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'

clear

# Mensagem de Boas-vindas
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}          INICIANDO A EXECUÇÃO DO LABORATÓRIO GSP323...           ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo

echo -e "${CYAN_TEXT}${BOLD_TEXT}--- CONFIGURAÇÃO DO AMBIENTE GCP ---${RESET_FORMAT}"

export PROJECT_ID=$(gcloud config get-value project)

read -p "$(echo -e ${YELLOW_TEXT}"Digite a REGIÃO do laboratório (ex: us-central1): "${RESET_FORMAT})" REGION
read -p "$(echo -e ${YELLOW_TEXT}"Digite o nome do DATASET do BigQuery: "${RESET_FORMAT})" DATASET
read -p "$(echo -e ${YELLOW_TEXT}"Digite o nome da TABELA do BigQuery: "${RESET_FORMAT})" TABLE
read -p "$(echo -e ${MAGENTA_TEXT}"Digite a URI completa da Tarefa 3 (ex: gs://.../arquivo.result): "${RESET_FORMAT})" TASK3_OUTPUT
read -p "$(echo -e ${MAGENTA_TEXT}"Digite a URI completa da Tarefa 4 (ex: gs://.../arquivo.result): "${RESET_FORMAT})" TASK4_OUTPUT

export BUCKET="${PROJECT_ID}-marking"
export TEMP_LOCATION="gs://${BUCKET}/temp"
export BQ_TEMP="gs://${BUCKET}/bigquery_temp"

echo -e "\n${GREEN_TEXT}${BOLD_TEXT}Configuração concluída. Iniciando os processos...${RESET_FORMAT}\n"

# --- TAREFA 1: Dataflow ---
echo -e "\n${YELLOW_TEXT}${BOLD_TEXT}Iniciando Tarefa 1: Dataflow...${RESET_FORMAT}"

# Criando recursos base
bq mk $DATASET 2>/dev/null || echo "Dataset já existe."
gsutil mb -l $REGION gs://$BUCKET 2>/dev/null || echo "Bucket já existe."

# Executando Job do Dataflow
gcloud dataflow jobs run batch-job-task1 \
  --gcs-location gs://dataflow-templates-$REGION/latest/GCS_Text_to_BigQuery \
  --region $REGION \
  --worker-machine-type e2-standard-2 \
  --staging-location $TEMP_LOCATION \
  --parameters \
javascriptTextTransformFunctionName=transform,\
JSONPath=gs://spls/gsp323/lab.schema,\
javascriptTextTransformGcsPath=gs://spls/gsp323/lab.js,\
inputFilePattern=gs://spls/gsp323/lab.csv,\
outputTable=$PROJECT_ID:$DATASET.$TABLE,\
bigQueryLoadingTemporaryDirectory=$BQ_TEMP

# --- TAREFA 2: Dataproc ---
echo -e "\n${MAGENTA_TEXT}${BOLD_TEXT}Iniciando Tarefa 2: Criação do Cluster Dataproc...${RESET_FORMAT}"
sleep 10

gcloud dataproc clusters create cluster-task2 \
    --region=$REGION \
    --num-workers 2 \
    --master-machine-type e2-standard-2 \
    --master-boot-disk-type pd-balanced \
    --master-boot-disk-size 100 \
    --worker-machine-type e2-standard-2 \
    --worker-boot-disk-type pd-balanced \
    --worker-boot-disk-size 100 \
    --image-version 2.0-debian10 \
    --project $PROJECT_ID

sleep 10

# Busca automaticamente o nome da VM e a Zona
export MASTER_NODE=$(gcloud compute instances list --filter="name ~ cluster-task2-m" --format="value(name)")
export MASTER_ZONE=$(gcloud compute instances list --filter="name ~ cluster-task2-m" --format="value(zone)")

echo -e "${BLUE_TEXT}Conectando à VM: $MASTER_NODE na Zona: $MASTER_ZONE${RESET_FORMAT}"

# Acesso via SSH e cópia de dados
gcloud compute ssh $MASTER_NODE --zone=$MASTER_ZONE --quiet --command="gsutil cp gs://spls/gsp323/data.txt . && hdfs dfs -put data.txt /data.txt"

# Submetendo Job do Spark
echo -e "${BLUE_TEXT}Enviando o Job do Spark...${RESET_FORMAT}"
gcloud dataproc jobs submit spark \
    --cluster=cluster-task2 \
    --region=$REGION \
    --class=org.apache.spark.examples.SparkPageRank \
    --jars=file:///usr/lib/spark/examples/jars/spark-examples.jar \
    --max-failures-per-hour=1 \
    -- /data.txt

# --- TAREFA 3: API Speech-to-Text ---
echo -e "\n${YELLOW_TEXT}${BOLD_TEXT}Iniciando Tarefa 3: API Speech-to-Text...${RESET_FORMAT}"

# Habilitando APIs necessárias
gcloud services enable apikeys.googleapis.com
gcloud services enable speech.googleapis.com

# Criando Chave de API
gcloud alpha services api-keys create --display-name="ml-api-key"

echo -e "${CYAN_TEXT}Aguardando a propagação da Chave de API (cerca de 30 segundos)...${RESET_FORMAT}"
sleep 30

# Recuperando a chave criada
KEY_NAME=$(gcloud alpha services api-keys list \
--format="value(name)" \
--filter="displayName=ml-api-key" \
--limit=1)

API_KEY=$(gcloud alpha services api-keys get-key-string "$KEY_NAME" \
--format="value(keyString)")

# Criando arquivo de requisição
cat > request.json <<EOF
{
  "config": {
    "encoding": "FLAC",
    "languageCode": "en-US"
  },
  "audio": {
    "uri": "gs://spls/gsp323/task3.flac"
  }
}
EOF

# Chamando a API Speech-to-Text
curl -s -X POST -H "Content-Type: application/json" \
--data-binary @request.json \
"https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" \
> result_task3.json

# Enviando resultado para o Cloud Storage
gsutil -h "Content-Type: application/json" cp result_task3.json $TASK3_OUTPUT

# --- TAREFA 4: API Natural Language ---
echo -e "\n${YELLOW_TEXT}${BOLD_TEXT}Iniciando Tarefa 4: API Natural Language...${RESET_FORMAT}"

gcloud ml language analyze-entities --content="Old Norse texts portray Odin as one-eyed and long-bearded, frequently wielding a spear named Gungnir and wearing a cloak and a broad hat." > result_task4.json

gsutil -h "Content-Type: application/json" cp result_task4.json $TASK4_OUTPUT

echo
echo "${CYAN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}            LABORATÓRIO CONCLUÍDO COM SUCESSO!         ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo "${WHITE_TEXT}Verifique no painel do laboratório se todas as tarefas${RESET_FORMAT}"
echo "${WHITE_TEXT}foram validadas corretamente.${RESET_FORMAT}"
echo
