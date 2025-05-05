./build.sh
aws ecs update-service --cluster cluster-bia --service task-def-bia-service --force-new-deployment