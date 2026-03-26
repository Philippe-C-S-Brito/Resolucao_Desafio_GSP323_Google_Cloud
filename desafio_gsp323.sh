#!/bin/bash

echo "======================================================="
echo "   Automação do Desafio GSP323 - Preparar Dados p/ ML  "
echo "======================================================="
echo ""
echo "Preencha com os dados do painel do seu laboratório:"
echo ""

read -p "1. ID do Projeto (ex: qwiklabs-gcp-...): " PROJECT_ID
read -p "2. Nome do Dataset do BigQuery (ex: lab_892): " DATASET_NAME
read -p "3. Nome da Tabela do BigQuery (ex: customers_451): " TABLE_NAME
read -p "4. Nome do Bucket (ex: qwiklabs-gcp-...-marking): " BUCKET_NAME
echo "---"
echo "ATENÇÃO: Nos itens 5 e 6, cole APENAS O NOME DO ARQUIVO FINAL."
echo "Exemplo correto: task3-gcs-963.result"
echo "---"
read -p "5. Arquivo de resultado da Tarefa 3: " SPEECH_FILE
read -p "6. Arquivo de resultado da Tarefa 4: " NL_FILE
echo "---"
read -p "7. Região do Laboratório (ex: us-east1 ou us-central1): " REGION

echo ""
echo "======================================================="
echo "⚙️ Configurando Ambiente e Rede..."
echo "======================================================="

# Limpa "gs://" caso o aluno tenha colado por engano
SPEECH_FILE="${SPEECH_FILE##*/}"
NL_FILE="${NL_FILE##*/}"

gcloud config set project $PROJECT_ID
gcloud config set compute/region $REGION

# Busca dinamicamente a 1ª zona válida da região
echo "-> Buscando uma zona válida para a região $REGION..."
ZONE=$(gcloud compute zones list --filter="region:($REGION)" --format="value(name)" --limit=1)
echo "-> Zona definida automaticamente: $ZONE"
gcloud config set compute/zone $ZONE

# Habilita Private Google Access e cria regra de firewall para o Dataproc não falhar
echo "-> Habilitando tráfego interno seguro na rede default..."
gcloud compute networks subnets update default \
    --region=$REGION \
    --enable-private-ip-google-access || true

gcloud compute firewall-rules create allow-internal-dataproc \
    --network default \
    --allow tcp,udp,icmp \
    --source-ranges 10.128.0.0/9 || true

echo "-> Aguardando 15s para a propagação das regras de rede..."
sleep 15

echo ""
echo "======================================================="
echo "🚀 TAREFA 1: Dataflow, BigQuery e Cloud Storage"
echo "======================================================="
echo "-> Criando Dataset..."
bq mk --location=$REGION $DATASET_NAME || true

echo "-> Baixando Schema e Criando Tabela..."
gsutil cp gs://spls/gsp323/lab.schema /tmp/lab.schema
bq mk --table $PROJECT_ID:$DATASET_NAME.$TABLE_NAME /tmp/lab.schema || true

echo "-> Criando Bucket..."
gsutil mb -p $PROJECT_ID -l $REGION gs://$BUCKET_NAME/ || true

echo "-> Submetendo Job do Dataflow (Roda em segundo plano)..."
gcloud dataflow jobs run desafio-dataflow-job \
    --gcs-location gs://dataflow-templates/latest/GCS_Text_to_BigQuery \
    --region $REGION \
    --worker-machine-type e2-standard-2 \
    --staging-location gs://$BUCKET_NAME/temp \
    --parameters \
javascriptTextTransformGcsPath=gs://spls/gsp323/lab.js,\
JSONPath=gs://spls/gsp323/lab.schema,\
javascriptTextTransformFunctionName=transform,\
outputTable=$PROJECT_ID:$DATASET_NAME.$TABLE_NAME,\
inputFilePattern=gs://spls/gsp323/lab.csv,\
bigQueryLoadingTemporaryDirectory=gs://$BUCKET_NAME/bigquery_temp || true

echo ""
echo "======================================================="
echo "🧠 TAREFA 2: Cluster e Job do Dataproc"
echo "======================================================="
gcloud dataproc clusters delete cluster-desafio --region=$REGION --quiet 2>/dev/null || true

echo "-> Criando Cluster Dataproc na zona $ZONE..."
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
        --project=$PROJECT_ID && break
    echo "⚠️ A rede do laboratório ainda está carregando. Tentando novamente em 30 segundos..."
    sleep 30
done

echo "-> Aguardando liberação da porta SSH (30 segundos)..."
sleep 30

echo "-> Copiando dados para o HDFS..."
for i in {1..4}; do
    gcloud compute ssh cluster-desafio-m --zone=$ZONE --quiet --command="hdfs dfs -cp gs://spls/gsp323/data.txt /data.txt" && break
    echo "⚠️ Conexão SSH recusada temporariamente. Tentando novamente em 20 segundos..."
    sleep 20
done

echo "-> Executando Job do Spark..."
gcloud dataproc jobs submit spark \
    --cluster=cluster-desafio \
    --region=$REGION \
    --class=org.apache.spark.examples.SparkPageRank \
    --jars=file:///usr/lib/spark/examples/jars/spark-examples.jar \
    --max-failures-per-hour=1 \
    -- /data.txt || true

echo ""
echo "======================================================="
echo "🎙️ TAREFAS 3 e 4: APIs de IA"
echo "======================================================="
echo "-> Executando API Speech-to-Text..."
cat <<EOF > speech_req.json
{
  "config": { "encoding": "FLAC", "languageCode": "en-US" },
  "audio": { "uri": "gs://spls/gsp323/task3.flac" }
}
EOF
curl -s -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     -H "Content-Type: application/json" --data-binary @speech_req.json \
     "https://speech.googleapis.com/v1/speech:recognize" > result_speech.json
gsutil cp result_speech.json gs://$BUCKET_NAME/$SPEECH_FILE || true

echo "-> Executando API Natural Language..."
cat <<EOF > nl_req.json
{
  "document":{
    "type":"PLAIN_TEXT",
    "content":"Old Norse texts portray Odin as one-eyed and long-bearded, frequently wielding a spear named Gungnir and wearing a cloak and a broad hat."
  },
  "encodingType":"UTF8"
}
EOF
curl -s -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     -H "Content-Type: application/json" --data-binary @nl_req.json \
     "https://language.googleapis.com/v1/documents:analyzeEntities" > result_nl.json
gsutil cp result_nl.json gs://$BUCKET_NAME/$NL_FILE || true

echo ""
echo "======================================================="
echo "✅ SCRIPT FINALIZADO!"
echo "As tarefas 2, 3 e 4 já devem estar prontas para validação."
echo "Aguarde o Dataflow concluir (Status: Succeeded) no painel"
echo "e clique em 'Verificar meu progresso' no laboratório!"
echo "======================================================="