#!/bin/bash
# Este script recebe o nome de uma instância EC2 como argumento e retorna o ID da instância se ela estiver em execução. Caso contrário, informa que a instância não existe ou está parada.

NOME=$1
INSTANCE_ID=$(aws ec2 describe-instances \
--filter "Name=tag:Name,Values=$NOME" \
--query "Reservations[].Instances[?State.Name == 'running'].InstanceId[]" \
--output text --profile formacaoaws)

if [ -z "$INSTANCE_ID" ]; then
    echo "A instância $NOME não existe ou está parada"
else
    echo "A instância $NOME tem o ID $INSTANCE_ID"
fi
