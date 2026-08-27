#!/bin/bash
set -e

script_dir=$(cd "$(dirname "$0")" && pwd)   # roda de qualquer pasta, sem mudar o cwd

ami_id=$(aws ssm get-parameter \
  --region us-east-1 \
  --name "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" \
  --query "Parameter.Value" --output text)

vpc_id=$(aws ec2 describe-vpcs \
  --filters Name=isDefault,Values=true \
  --query "Vpcs[0].VpcId" --output text)

subnet_id=$(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values=$vpc_id Name=availabilityZone,Values=us-east-1b \
  --query "Subnets[0].SubnetId" --output text)

security_group_id=$(aws ec2 describe-security-groups \
  --group-names "bia-dev-zona_b" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

if [ -z "$security_group_id" ]; then
    echo ">[ERRO] Security group bia-dev-zona_b não foi criado na VPC $vpc_id"
    exit 1
fi

user_data=$(base64 -i $script_dir/bia/scripts/user_data_ec2_zona_b.sh | tr -d '\n')

aws ec2 run-instances \
  --image-id "$ami_id" \
  --count 1 \
  --instance-type t3.micro \
  --network-interfaces "DeviceIndex=0,SubnetId=$subnet_id,Groups=$security_group_id,AssociatePublicIpAddress=true" \
  --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":15,"VolumeType":"gp2"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=bia-dev-zona_b}]' \
  --iam-instance-profile Name=role-acesso-ssm \
  --user-data "$user_data"
