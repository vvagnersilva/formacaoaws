#!/bin/bash

# Para executar esse script precisa passar o parametro de instance-id da instancia que deseja acessar o log do SSM Agent.
# Exemplo de uso: ./tail.sh i-046eb4ad1fd45ca62

INSTANCE_ID=$1

if [ -z "$INSTANCE_ID" ]; then
  echo "Uso: ./tail.sh <instance-id>"
  exit 1
fi

echo "Conectando na instancia $INSTANCE_ID para tail do SSM Agent log..."

aws ssm start-session \
  --target "$INSTANCE_ID" \
  --region us-east-1 \
  --profile formacaoaws \
  --document-name AWS-StartInteractiveCommand \
  --parameters command="sudo tail -f /var/log/amazon/ssm/amazon-ssm-agent.log"
