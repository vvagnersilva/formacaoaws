# ./06-1-ligar-porteiro.sh bia-dev

NOME_INSTANCIA=$1
INSTANCE_ID=$(aws ec2 describe-instances \
   --filter "Name=tag:Name,Values=$NOME_INSTANCIA" \
   --query "Reservations[*].Instances[?State.Name=='stopped'].InstanceId" \
   --output text --profile formacao-aws)

if [ -z $INSTANCE_ID ]; then
    echo "A instancia $NOME_INSTANCIA não existe ou está parada"
else
    echo "A instancia $NOME_INSTANCIA tem o ID $INSTANCE_ID"
fi

STATUS_PORTEIRO=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
   --query "Reservations[*].Instances[0].State.Name" \
   --output text --profile formacao-aws)

if [ "$STATUS_PORTEIRO" != "running" ]; then
    echo "Iniciando EC2 $INSTANCE_ID"
    aws ec2 start-instances --instance-ids $INSTANCE_ID \
         --profile formacao-aws &> /dev/null &
    echo "Aguardando 30s para o porteiro ficar pronto ..."
    sleep 30
else
    echo "Porteiro EC2 com ID $INSTANCE_ID ja esta rodando"
fi

#create the port forwarding tunnel
aws ssm start-session \
    --target $INSTANCE_ID \
    --document-name AWS-StartPortForwardingSession \
    --parameters '{"portNumber":["3001"],"localPortNumber":["3002"]}' \
    --profile formacao-aws
