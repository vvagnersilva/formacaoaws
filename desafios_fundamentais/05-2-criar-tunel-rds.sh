NOME_INSTANCIA=$1
NOME_RDS=$2

INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$NOME_INSTANCIA" --query "Reservations[*].Instances[?State.Name=='running'].InstanceId" \
  --output text --profile formacao-aws)

if [ -z $INSTANCE_ID ]; then
    echo "A instancia $NOME_INSTANCIA não existe ou está parada"
else
    echo "A instancia $NOME_INSTANCIA tem o ID $INSTANCE_ID"
fi

DB_INSTANCE=$(aws rds describe-db-instances \
            --db-instance-identifier $NOME_RDS \
            --query "DBInstances[].Endpoint.Address" \
            --output text --profile formacao-aws)

if [ -z $DB_INSTANCE ]; then
    echo "O banco de dados $NOME_RDS não existe"
else
    echo "O banco de dados $NOME_RDS tem o endpoint $DB_INSTANCE"
fi

aws ssm start-session --target $INSTANCE_ID \
            --document-name AWS-StartPortForwardingSessionToRemoteHost \
            --parameters '{"host":["'"$DB_INSTANCE"'"],"portNumber":["5432"],"localPortNumber":["5433"]}' \
            --output text --profile formacao-aws