#!/bin/bash

# Definição de Cores
CYAN_TEXT=$'\033[0;96m'
GREEN_TEXT=$'\033[0;92m'
YELLOW_TEXT=$'\033[0;93m'
MAGENTA_TEXT=$'\033[0;95m'
BLUE_TEXT=$'\033[0;94m'
WHITE_TEXT=$'\033[0;97m'
RESET_FORMAT=$'\033[0m'
BOLD_TEXT=$'\033[1m'

clear

echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}          INICIANDO A EXECUÇÃO DO LABORATÓRIO GSP323...           ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}==================================================================${RESET_FORMAT}"
echo

echo "${YELLOW_TEXT}${BOLD_TEXT}Preencha com os dados do painel do seu laboratório:${RESET_FORMAT}"
echo

read -p "1. ID do Projeto (ex: qwiklabs-gcp-...): " PROJECT_ID
read -p "2. Nome do Dataset do BigQuery (ex: lab_892): " DATASET_NAME
read -p "3. Nome da Tabela do BigQuery (ex: customers_451): " TABLE_NAME
read -p "4. Nome do Bucket (ex: qwiklabs-gcp-...-marking): " BUCKET_NAME
echo "${MAGENTA_TEXT}ATENÇÃO: Nos itens 5 e 6, cole APENAS O NOME DO ARQUIVO FINAL. Ex: task3-gcs-963.result${RESET_FORMAT}"
read -p "5. Arquivo de resultado da Tarefa 3: " SPEECH_FILE
read -p "6. Arquivo de resultado da Tarefa 4: " NL_FILE
read -p "7. Região do Laboratório (ex: us-east1 ou us-central1): " REGION

# Limpeza de variáveis (remove "gs://" se o aluno colar por engano)
SPEECH_FILE="${SPEECH_FILE##*/}"
NL_FILE="${NL_FILE##*/}"

echo ""
echo "${GREEN_TEXT}${BOLD_TEXT}⚙️ Configurando Ambiente e Rede...${RESET_FORMAT}"
gcloud config set project $PROJECT_ID --quiet
gcloud config set compute/region $REGION --quiet

# Busca dinamicamente a 1ª zona válida da região
ZONE=$(gcloud compute zones list --filter="region:($REGION)" --format="value(name)" --limit=1)
gcloud config set compute/zone $ZONE --quiet

# Habilita rede interna para o Dataproc não falhar (Private Google Access e Firewall)
gcloud compute networks subnets update default --region=$REGION --enable-private-ip-google-access --quiet || true
gcloud compute firewall-rules create allow-internal-dataproc --network default --allow tcp,udp,icmp --source-ranges 10.128.0.0/9 --quiet || true

echo ""
echo "${YELLOW_TEXT}${BOLD_TEXT}🚀 TAREFA 1: Dataflow, BigQuery e Cloud Storage${RESET_FORMAT}"
bq mk --location=$REGION $DATASET_NAME 2>/dev/null || true

# Escrevendo o schema estendido para evitar erros de formatação JSON
cat <<EOF > lab.schema
[
    {"type":"STRING","name":"guid"},
    {"type":"BOOLEAN","name":"isActive"},
    {"type":"STRING","name":"firstname"},
    {"type":"STRING","name":"surname"},
    {"type":"STRING","name":"company"},
    {"type":"STRING","name":"email"},
    {"type":"STRING","name":"phone"},
    {"type":"STRING","name":"address"},
    {"type":"STRING","name":"about"},
    {"type":"TIMESTAMP","name":"registered"},
    {"type":"FLOAT","name":"latitude"},
    {"type":"FLOAT","name":"longitude"}
]
EOF

bq mk --table $PROJECT_ID:$DATASET_NAME.$TABLE_NAME lab.schema 2>/dev/null || true
gsutil mb -p $PROJECT_ID -l $REGION gs://$BUCKET_NAME/ 2>/dev/null || true

gcloud dataflow jobs run batch-job-task1 \
    --gcs-location gs://dataflow-templates/latest/GCS_Text_to_BigQuery \
    --region $REGION \
    --worker-machine-type e2-standard-2 \
    --staging-location gs://$BUCKET_NAME/temp \
    --parameters \
javascriptTextTransformFunctionName=transform,\
JSONPath=gs://spls/gsp323/lab.schema,\
javascriptTextTransformGcsPath=gs://spls/gsp323/lab.js,\
inputFilePattern=gs://spls/gsp323/lab.csv,\
outputTable=$PROJECT_ID:$DATASET_NAME.$TABLE_NAME,\
bigQueryLoadingTemporaryDirectory=gs://$BUCKET_NAME/bigquery_temp --quiet || true

echo ""
echo "${BLUE_TEXT}${BOLD_TEXT}🧠 TAREFA 2: Cluster e Job do Dataproc (Com Verificação de Rede)${RESET_FORMAT}"
gcloud dataproc clusters delete cluster-desafio --region=$REGION --quiet 2>/dev/null || true

# Loop blindado para criação do Dataproc (Tenta 4 vezes caso a rede atrase)
for i in {1..4}; do
    gcloud dataproc clusters create cluster-desafio \
        --region=$REGION \
        --zone=$ZONE \
        --master-machine-type=e2-standard-2 \
        --master-boot-disk-type=pd-balanced \
        --master-boot-disk-size=100GB \
        --worker-machine-type=e2-standard-2 \
        --worker-boot-disk-type=pd-balanced \
        --worker-boot-disk-size=100GB \
        --num-workers=2 \
        --project=$PROJECT_ID --quiet && break
    echo "⚠️ A rede do laboratório ainda está carregando. Tentando novamente em 30 segundos..."
    sleep 30
done

echo "-> Aguardando liberação da porta SSH (30 segundos)..."
sleep 30

# Loop blindado para SSH
for i in {1..4}; do
    gcloud compute ssh cluster-desafio-m --zone=$ZONE --quiet --command="hdfs dfs -cp gs://spls/gsp323/data.txt /data.txt" && break
    echo "⚠️ Conexão SSH recusada temporariamente. Tentando novamente em 20 segundos..."
    sleep 20
done

gcloud dataproc jobs submit spark \
    --cluster=cluster-desafio \
    --region=$REGION \
    --class=org.apache.spark.examples.SparkPageRank \
    --jars=file:///usr/lib/spark/examples/jars/spark-examples.jar \
    --max-failures-per-hour=1 \
    --quiet \
    -- /data.txt || true

echo ""
echo "${MAGENTA_TEXT}${BOLD_TEXT}🎙️ TAREFAS 3 e 4: APIs de IA${RESET_FORMAT}"

# Ativando as APIs necessárias (Speech, Language e API Keys)
gcloud services enable apikeys.googleapis.com \
                       speech.googleapis.com \
                       language.googleapis.com --quiet

gcloud alpha services api-keys create --display-name="ml-api-key" --quiet

echo "Aguardando 30 segundos para a propagação da Chave de API..."
sleep 30

KEY_NAME=$(gcloud alpha services api-keys list --format="value(name)" --filter="displayName=ml-api-key" --limit=1)
API_KEY=$(gcloud alpha services api-keys get-key-string "$KEY_NAME" --format="value(keyString)")

# TAREFA 3: Speech to Text
cat <<EOF > speech_req.json
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

curl -s -X POST -H "Content-Type: application/json" --data-binary @speech_req.json "https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" > result_speech.json

# Upload forçando o cabeçalho JSON
gsutil -h "Content-Type: application/json" cp result_speech.json gs://$BUCKET_NAME/$SPEECH_FILE

# TAREFA 4: Natural Language
gcloud ml language analyze-entities --content="Old Norse texts portray Odin as one-eyed and long-bearded, frequently wielding a spear named Gungnir and wearing a cloak and a broad hat." > result_nl.json

# Upload forçando o cabeçalho JSON
gsutil -h "Content-Type: application/json" cp result_nl.json gs://$BUCKET_NAME/$NL_FILE

echo ""
echo "${CYAN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}            LABORATÓRIO CONCLUÍDO COM SUCESSO!         ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo "${WHITE_TEXT}As tarefas 2, 3 e 4 já podem ser validadas.${RESET_FORMAT}"
echo "${WHITE_TEXT}Aguarde o Dataflow concluir (Status: Succeeded) no painel${RESET_FORMAT}"
echo "${WHITE_TEXT}para validar a Tarefa 1!${RESET_FORMAT}"
echo ""
