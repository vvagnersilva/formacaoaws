###UNZIP ###
NOME=$1
INSTANCE_ID=$(aws ec2 describe-instances \
            --filter "Name=tag:Name,Values=$NOME" \
            --query "Reservations[].Instances[?State.Name == 'running'].InstanceId[]" \
            --output text --profile formacao-aws)

if [ -z "$INSTANCE_ID" ]; then
    echo "Instancia não encontrada"
    exit 1
fi

echo "Instancia: " $INSTANCE_ID
