#!/bin/bash

# Este script recebe o nome de uma instância EC2 como argumento e inicia um túnel
# Para executar o script, use: ./05-1-criar-tunel-propria-ec2.sh <nome-da-instancia>

NOME=$1
INSTANCE_ID=$(aws ec2 describe-instances \
--filter "Name=tag:Name,Values=$NOME" \
--query "Reservations[].Instances[?State.Name == 'running'].InstanceId[]" \
--output text --profile formacaoaws)

echo "Iniciando tunel na porta 3002 do SSM na instância $NOME"

 if [ -z "$INSTANCE_ID" ]; then
        echo "A instância $NOME não existe ou está parada"
        exit 1
    else
        echo "A instância encontrada: $INSTANCE_ID"
    fi

aws ssm start-session --target "$INSTANCE_ID" \
    --region us-east-1 \
    --document-name AWS-StartPortForwardingSession \
    --parameters '{"portNumber":["3001"],"localPortNumber":["3002"]}' \
    --profile formacaoaws
