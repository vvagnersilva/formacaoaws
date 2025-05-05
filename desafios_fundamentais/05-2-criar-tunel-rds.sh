###UNZIP ###
NOME=$1
NOME_RDS=$2

INSTANCE_ID=$(aws ec2 describe-instances \
            --filter "Name=tag:Name,Values=$NOME" \
            --query "Reservations[].Instances[?State.Name == 'running'].InstanceId[]" \
            --output text --profile formacao-aws)

if [ -z "$INSTANCE_ID" ]; then
    echo "Instancia não encontrada"
    exit 1
fi

echo "Instancia: " $INSTANCE_ID

DNS_PRIVADO_DO_RDS=$(aws rds describe-db-instances \
            --db-instance-identifier $NOME_RDS \
            --query "DBInstances[].Endpoint.Address" \
            --output text --profile formacao-aws)

if [ -z "$DNS_PRIVADO_DO_RDS" ]; then
    echo "RDS não encontrado"
    exit 1
fi

echo "DNS Privado do RDS: " $DNS_PRIVADO_DO_RDS

#create the port forwarding tunnel
aws ssm start-session \
    --target $INSTANCE_ID \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters '{"host":["'$DNS_PRIVADO_DO_RDS'"],"portNumber":["5432"],"localPortNumber":["5433"]}' \
    --output text --profile formacao-aws


