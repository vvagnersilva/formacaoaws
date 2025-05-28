vpc_id=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query "Vpcs[0].VpcId" --output text --profile formacao-aws 2>/dev/null)
subnet_id=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$vpc_id Name=availabilityZone,Values=us-east-1b --query "Subnets[0].SubnetId" --output text --profile formacao-aws)
security_group_id=$(aws ec2 describe-security-groups --group-names "bia-dev" --query "SecurityGroups[0].GroupId" --output text --profile formacao-aws)

if [ -z "$security_group_id" ]; then
    echo ">[ERRO] Security group bia-zonab não foi criado na VPC $vpc_id"
    exit 1
fi

aws ec2 run-instances --image-id ami-0953476d60561c955 --count 1 --instance-type t2.micro \
--security-group-ids $security_group_id --subnet-id $subnet_id --associate-public-ip-address \
--block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":15,"VolumeType":"gp2"}}]' \
--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=bia-zonab}]' \
--iam-instance-profile Name=role-acesso-ssm --user-data file://user_data_ec2_zona_b.sh\
--profile formacao-aws