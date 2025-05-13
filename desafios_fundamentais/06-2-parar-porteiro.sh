# ./06-2-parar-porteiro.sh bia-dev

NOME_INSTANCIA=$1
INSTANCE_ID=$(aws ec2 describe-instances \
   --filter "Name=tag:Name,Values=$NOME_INSTANCIA" \
   --query "Reservations[*].Instances[?State.Name=='running'].InstanceId" \
   --output text --profile formacao-aws)

if [ -z $INSTANCE_ID ]; then
    echo "A instancia $NOME_INSTANCIA não existe ou está parada"
else
    echo "A instancia $NOME_INSTANCIA tem o ID $INSTANCE_ID"
fi

STATUS_PORTEIRO=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
   --query "Reservations[*].Instances[0].State.Name" \
   --output text --profile formacao-aws)

if [ "$STATUS_PORTEIRO" == "running" ]; then
    echo "Parando EC2 $INSTANCE_ID"
    aws ec2 stop-instances --instance-ids $INSTANCE_ID \
         --profile formacao-aws &> /dev/null &
    echo "Porteiro ja esta sendo parado ..."
else
    echo "Porteiro EC2 com ID $INSTANCE_ID ja esta parado"
fi
