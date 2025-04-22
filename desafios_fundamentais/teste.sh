#!/bin/bash

# Defina o nome do seu bucket S3
BUCKET_NAME="seu-bucket-s3"

# Caminho para a pasta local que você quer fazer o upload
LOCAL_FOLDER="build"

# Comando para sincronizar a pasta local com o S3
aws s3 sync "$LOCAL_FOLDER" "s3://$BUCKET_NAME/"

# Mensagem de confirmação
echo "A pasta '$LOCAL_FOLDER' foi enviada com sucesso para o bucket '$BUCKET_NAME'!"

