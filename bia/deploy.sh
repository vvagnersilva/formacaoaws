./build.sh
aws ecs update-service --cluster cluster-bia --service service_bia --force-new-deployment