ECR_REGISTRY="455958489218.dkr.ecr.us-east-1.amazonaws.com"
VITE_API_URL=$(grep VITE_API_URL client/.env | cut -d '=' -f2)

aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY
docker build --build-arg VITE_API_URL=$VITE_API_URL -t bia .
docker tag bia:latest $ECR_REGISTRY/bia:latest
docker push $ECR_REGISTRY/bia:latest
