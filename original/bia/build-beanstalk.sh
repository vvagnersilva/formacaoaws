versao=$(git rev-parse HEAD | cut -c 1-7)
aws ecr get-login-password --region us-east-1 --profile formacao-aws| docker login --username AWS --password-stdin 158128612190.dkr.ecr.us-east-1.amazonaws.com
docker build -t bia-beanstalk .
docker tag bia-beanstalk:latest 158128612190.dkr.ecr.us-east-1.amazonaws.com/bia-beanstalk:$versao
docker push 158128612190.dkr.ecr.us-east-1.amazonaws.com/bia-beanstalk:$versao
rm .env 2> /dev/null
./gerar-compose.sh
rm bia-versao-*.zip
zip -r bia-versao-$versao.zip docker-compose.yml