#!/bin/bash

AMBIENTE=$1
API_URL="http://52.90.106.60"

echo "Vou iniciar o deploy no Ambiente: "$AMBIENTE
echo "O endereço da API é: "$API_URL

if [ "$AMBIENTE" != "hom" ] && [ "$AMBIENTE" != "prod" ]; then
    echo "Ambiente inválido"
    exit 1
fi

echo "Fazendo deploy ..."

. react.sh
source s3.sh
 
build $API_URL

envio_s3

echo "Finalizado"