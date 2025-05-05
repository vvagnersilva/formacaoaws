###UNZIP ###
aws ssm start-session --target i-0748a09cd35923d82  --profile formacao-aws
sudo su && tail -f /var/log/amazon/ssm/amazon-ssm-agent.log