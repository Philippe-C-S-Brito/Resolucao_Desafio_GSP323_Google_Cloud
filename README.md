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

\`\`\`bash
curl -LO https://raw.githubusercontent.com/Philippe-C-S-Brito/Resolucao_Desafio_GSP323_Google_Cloud/main/desafio_gsp323.sh
sudo chmod +x desafio_gsp323.sh
./desafio_gsp323.sh
\`\`\`

3. O script vai pausar e perguntar pelas **7 informações** que você separou no Passo 1. Cole uma a uma e aperte `ENTER`.
4. Aguarde a finalização. Quando a mensagem `✅ SCRIPT FINALIZADO!` aparecer, você já poderá validar as tarefas 2, 3 e 4. 
5. Para a **Tarefa 1**, vá no menu `Dataflow > Jobs` no console e espere o status ficar verde (`Succeeded`) antes de validar.

Bons estudos!