#!/bin/bash

# =============================================================================
# Script de Provisionamento de Infraestrutura - Projeto BIA
# =============================================================================
# Provisiona a infraestrutura ECS completa nos dois cenários:
#   1) Sem ALB — cluster-bia + service-bia + EC2 na zona A
#   2) Com ALB  — cluster-bia-alb + service-bia-alb + EC2 na zona A e zona B
#
# Pré-requisitos (já devem existir):
#   - Security groups: bia-web (sem ALB), bia-ec2 / bia-alb (com ALB)
#   - RDS acessível pelo security group bia-db
#   - ECR com repositório "bia" e imagem disponível
#   - IAM role: ecsTaskExecutionRole, role-acesso-ssm
#   - ALB "bia-alb" e Target Group "tg-bia-alb" (cenário com ALB)
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Configurações globais
# -----------------------------------------------------------------------------
AWS_REGION="us-east-1"
ACCOUNT_ID="455958489218"
ECR_REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
ECR_REPO="bia"
REPOSITORY_URI="$ECR_REGISTRY/$ECR_REPO"

# Clusters
CLUSTER_SEM_ALB="cluster-bia"
CLUSTER_COM_ALB="cluster-bia-alb"

# Task Definitions
TASK_DEF_SEM_ALB="task-def-bia"
TASK_DEF_COM_ALB="task-def-bia-alb"

# Services
SERVICE_SEM_ALB="service-bia"
SERVICE_COM_ALB="service-bia-alb"

# EC2
INSTANCE_TYPE_SEM_ALB="t3.micro"
INSTANCE_TYPE_COM_ALB="t3.micro"
IAM_PROFILE="ecsInstanceRole"   # role para instâncias ECS (não usar role-acesso-ssm aqui)
ECS_CLUSTER_SEM_ALB="$CLUSTER_SEM_ALB"
ECS_CLUSTER_COM_ALB="$CLUSTER_COM_ALB"

# -----------------------------------------------------------------------------
# Funções auxiliares
# -----------------------------------------------------------------------------
info()    { echo -e "\n\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\n\033[1;32m[OK]\033[0m $1"; }
error()   { echo -e "\n\033[1;31m[ERRO]\033[0m $1" >&2; exit 1; }
warn()    { echo -e "\n\033[1;33m[AVISO]\033[0m $1"; }
skip()    { echo -e "\n\033[1;36m[SKIP]\033[0m $1 (já existe)"; }

# Busca o ID da VPC default
get_vpc_id() {
  aws ec2 describe-vpcs \
    --region "$AWS_REGION" \
    --filters Name=isDefault,Values=true \
    --query "Vpcs[0].VpcId" \
    --output text
}

# Busca subnet de uma AZ específica na VPC default
get_subnet_id() {
  local az=$1
  local vpc_id=$2
  aws ec2 describe-subnets \
    --region "$AWS_REGION" \
    --filters "Name=vpc-id,Values=$vpc_id" "Name=availabilityZone,Values=$az" \
    --query "Subnets[0].SubnetId" \
    --output text
}

# Busca ID de um security group pelo nome
get_sg_id() {
  local name=$1
  aws ec2 describe-security-groups \
    --region "$AWS_REGION" \
    --group-names "$name" \
    --query "SecurityGroups[0].GroupId" \
    --output text 2>/dev/null || echo ""
}

# Busca a AMI ECS Optimized mais recente
get_ecs_ami() {
  aws ssm get-parameter \
    --region "$AWS_REGION" \
    --name "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id" \
    --query "Parameter.Value" \
    --output text
}

# Verifica se cluster ECS existe
cluster_existe() {
  local cluster=$1
  local status
  status=$(aws ecs describe-clusters \
    --region "$AWS_REGION" \
    --clusters "$cluster" \
    --query "clusters[0].status" \
    --output text 2>/dev/null || echo "MISSING")
  [[ "$status" == "ACTIVE" ]]
}

# Verifica se task definition existe
task_def_existe() {
  local td=$1
  aws ecs describe-task-definition \
    --region "$AWS_REGION" \
    --task-definition "$td" \
    --query "taskDefinition.taskDefinitionArn" \
    --output text &>/dev/null 2>&1
}

# Verifica se service ECS existe e está ativo
service_existe() {
  local cluster=$1
  local service=$2
  local status
  status=$(aws ecs describe-services \
    --region "$AWS_REGION" \
    --cluster "$cluster" \
    --services "$service" \
    --query "services[0].status" \
    --output text 2>/dev/null || echo "MISSING")
  [[ "$status" == "ACTIVE" ]]
}

# Verifica se EC2 com determinada tag Name está rodando
ec2_existe() {
  local name=$1
  local count
  count=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=$name" "Name=instance-state-name,Values=running,pending" \
    --query "length(Reservations)" \
    --output text)
  [[ "$count" -gt 0 ]]
}

# Gera user data para instância ECS (registra no cluster correto)
gerar_user_data_ecs() {
  local cluster_name=$1
  cat <<EOF
#!/bin/bash
echo ECS_CLUSTER=$cluster_name >> /etc/ecs/ecs.config
EOF
}

# Lança uma instância EC2 ECS Optimized
lancar_ec2_ecs() {
  local name=$1
  local az=$2
  local sg_id=$3
  local subnet_id=$4
  local instance_type=$5
  local cluster_name=$6
  local ami=$7

  info "Lançando EC2 '$name' ($instance_type) na $az..."

  USER_DATA=$(gerar_user_data_ecs "$cluster_name" | base64 | tr -d '\n')

  INSTANCE_ID=$(aws ec2 run-instances \
    --region "$AWS_REGION" \
    --image-id "$ami" \
    --count 1 \
    --instance-type "$instance_type" \
    --iam-instance-profile "Name=$IAM_PROFILE" \
    --network-interfaces "DeviceIndex=0,SubnetId=$subnet_id,Groups=$sg_id,AssociatePublicIpAddress=true" \
    --user-data "$USER_DATA" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$name}]" \
    --query "Instances[0].InstanceId" \
    --output text)

  success "EC2 lançada: $INSTANCE_ID ($name)"
  echo "$INSTANCE_ID"
}

# -----------------------------------------------------------------------------
# Provisionamento — Cenário 1: Sem ALB
# -----------------------------------------------------------------------------
provisionar_sem_alb() {
  info "=== PROVISIONANDO CENÁRIO 1: SEM ALB ==="

  VPC_ID=$(get_vpc_id)
  info "VPC default: $VPC_ID"

  SUBNET_A=$(get_subnet_id "us-east-1a" "$VPC_ID")
  info "Subnet zona A: $SUBNET_A"

  SG_WEB=$(get_sg_id "bia-web")
  [[ -z "$SG_WEB" || "$SG_WEB" == "None" ]] && error "Security group 'bia-web' não encontrado."
  info "Security group bia-web: $SG_WEB"

  ECS_AMI=$(get_ecs_ami)
  info "AMI ECS Optimized: $ECS_AMI"

  # 1. Cluster ECS
  if cluster_existe "$CLUSTER_SEM_ALB"; then
    skip "Cluster '$CLUSTER_SEM_ALB'"
  else
    info "Criando cluster '$CLUSTER_SEM_ALB'..."
    aws ecs create-cluster \
      --region "$AWS_REGION" \
      --cluster-name "$CLUSTER_SEM_ALB" \
      --output json > /dev/null
    success "Cluster '$CLUSTER_SEM_ALB' criado."
  fi

  # 2. Task Definition
  if task_def_existe "$TASK_DEF_SEM_ALB"; then
    skip "Task Definition '$TASK_DEF_SEM_ALB'"
  else
    info "Registrando Task Definition '$TASK_DEF_SEM_ALB'..."
    aws ecs register-task-definition \
      --region "$AWS_REGION" \
      --family "$TASK_DEF_SEM_ALB" \
      --execution-role-arn "arn:aws:iam::${ACCOUNT_ID}:role/ecsTaskExecutionRole" \
      --network-mode bridge \
      --requires-compatibilities EC2 \
      --container-definitions "[
        {
          \"name\": \"bia\",
          \"image\": \"${REPOSITORY_URI}:latest\",
          \"cpu\": 1024,
          \"memoryReservation\": 400,
          \"portMappings\": [{\"containerPort\": 8080, \"hostPort\": 80, \"protocol\": \"tcp\"}],
          \"essential\": true,
          \"environment\": [
            {\"name\": \"DB_NAME\", \"value\": \"bia\"},
            {\"name\": \"DB_USER\", \"value\": \"postgres\"},
            {\"name\": \"DB_PWD\",  \"value\": \"1BZuaUz3Zg52HN47qMRg\"},
            {\"name\": \"DB_HOST\", \"value\": \"bia.culoosoiuhai.us-east-1.rds.amazonaws.com\"},
            {\"name\": \"DB_PORT\", \"value\": \"5432\"}
          ],
          \"logConfiguration\": {
            \"logDriver\": \"awslogs\",
            \"options\": {
              \"awslogs-group\": \"/ecs/${TASK_DEF_SEM_ALB}\",
              \"awslogs-create-group\": \"true\",
              \"awslogs-region\": \"${AWS_REGION}\",
              \"awslogs-stream-prefix\": \"ecs\"
            }
          }
        }
      ]" \
      --output json > /dev/null
    success "Task Definition '$TASK_DEF_SEM_ALB' registrada."
  fi

  # 3. EC2 ECS Optimized (zona A)
  if ec2_existe "bia-ecs-zona-a"; then
    skip "EC2 'bia-ecs-zona-a'"
  else
    lancar_ec2_ecs "bia-ecs-zona-a" "us-east-1a" "$SG_WEB" "$SUBNET_A" \
      "$INSTANCE_TYPE_SEM_ALB" "$ECS_CLUSTER_SEM_ALB" "$ECS_AMI"
  fi

  # 4. Service ECS
  if service_existe "$CLUSTER_SEM_ALB" "$SERVICE_SEM_ALB"; then
    skip "Service '$SERVICE_SEM_ALB'"
  else
    info "Aguardando instância registrar no cluster (30s)..."
    sleep 30

    info "Criando service '$SERVICE_SEM_ALB'..."
    aws ecs create-service \
      --region "$AWS_REGION" \
      --cluster "$CLUSTER_SEM_ALB" \
      --service-name "$SERVICE_SEM_ALB" \
      --task-definition "$TASK_DEF_SEM_ALB" \
      --desired-count 1 \
      --launch-type EC2 \
      --scheduling-strategy REPLICA \
      --deployment-controller type=ECS \
      --deployment-configuration "minimumHealthyPercent=0,maximumPercent=100" \
      --availability-zone-rebalancing DISABLED \
      --placement-strategy "type=spread,field=attribute:ecs.availability-zone" "type=spread,field=instanceId" \
      --output json > /dev/null
    success "Service '$SERVICE_SEM_ALB' criado."
  fi

  echo ""
  echo "┌──────────────────────────────────────────────────────┐"
  echo "│         ✅  Cenário 1 (Sem ALB) Provisionado!        │"
  echo "├──────────────────────────────────────────────────────┤"
  printf "│  Cluster:   %-40s│\n" "$CLUSTER_SEM_ALB"
  printf "│  Service:   %-40s│\n" "$SERVICE_SEM_ALB"
  printf "│  Task Def:  %-40s│\n" "$TASK_DEF_SEM_ALB"
  echo "└──────────────────────────────────────────────────────┘"
}

# -----------------------------------------------------------------------------
# Provisionamento — Cenário 2: Com ALB
# -----------------------------------------------------------------------------
provisionar_com_alb() {
  info "=== PROVISIONANDO CENÁRIO 2: COM ALB ==="

  VPC_ID=$(get_vpc_id)
  info "VPC default: $VPC_ID"

  SUBNET_A=$(get_subnet_id "us-east-1a" "$VPC_ID")
  SUBNET_B=$(get_subnet_id "us-east-1b" "$VPC_ID")
  info "Subnet zona A: $SUBNET_A"
  info "Subnet zona B: $SUBNET_B"

  SG_EC2=$(get_sg_id "bia-ec2")
  [[ -z "$SG_EC2" || "$SG_EC2" == "None" ]] && error "Security group 'bia-ec2' não encontrado."
  info "Security group bia-ec2: $SG_EC2"

  # Verificar ALB e Target Group
  TG_ARN=$(aws elbv2 describe-target-groups \
    --region "$AWS_REGION" \
    --names "tg-bia-alb" \
    --query "TargetGroups[0].TargetGroupArn" \
    --output text 2>/dev/null || echo "")
  [[ -z "$TG_ARN" || "$TG_ARN" == "None" ]] && error "Target Group 'tg-bia-alb' não encontrado. Crie o ALB e o Target Group antes de executar este cenário."
  info "Target Group tg-bia-alb: $TG_ARN"

  ECS_AMI=$(get_ecs_ami)
  info "AMI ECS Optimized: $ECS_AMI"

  # 1. Cluster ECS
  if cluster_existe "$CLUSTER_COM_ALB"; then
    skip "Cluster '$CLUSTER_COM_ALB'"
  else
    info "Criando cluster '$CLUSTER_COM_ALB'..."
    aws ecs create-cluster \
      --region "$AWS_REGION" \
      --cluster-name "$CLUSTER_COM_ALB" \
      --output json > /dev/null
    success "Cluster '$CLUSTER_COM_ALB' criado."
  fi

  # 2. Task Definition
  if task_def_existe "$TASK_DEF_COM_ALB"; then
    skip "Task Definition '$TASK_DEF_COM_ALB'"
  else
    info "Registrando Task Definition '$TASK_DEF_COM_ALB'..."
    aws ecs register-task-definition \
      --region "$AWS_REGION" \
      --family "$TASK_DEF_COM_ALB" \
      --execution-role-arn "arn:aws:iam::${ACCOUNT_ID}:role/ecsTaskExecutionRole" \
      --network-mode bridge \
      --requires-compatibilities EC2 \
      --container-definitions "[
        {
          \"name\": \"bia\",
          \"image\": \"${REPOSITORY_URI}:latest\",
          \"cpu\": 1024,
          \"memoryReservation\": 400,
          \"portMappings\": [{\"containerPort\": 8080, \"hostPort\": 0, \"protocol\": \"tcp\"}],
          \"essential\": true,
          \"environment\": [
            {\"name\": \"DB_NAME\", \"value\": \"bia\"},
            {\"name\": \"DB_USER\", \"value\": \"postgres\"},
            {\"name\": \"DB_PWD\",  \"value\": \"1BZuaUz3Zg52HN47qMRg\"},
            {\"name\": \"DB_HOST\", \"value\": \"bia.culoosoiuhai.us-east-1.rds.amazonaws.com\"},
            {\"name\": \"DB_PORT\", \"value\": \"5432\"}
          ],
          \"logConfiguration\": {
            \"logDriver\": \"awslogs\",
            \"options\": {
              \"awslogs-group\": \"/ecs/${TASK_DEF_COM_ALB}\",
              \"awslogs-create-group\": \"true\",
              \"awslogs-region\": \"${AWS_REGION}\",
              \"awslogs-stream-prefix\": \"ecs\"
            }
          }
        }
      ]" \
      --output json > /dev/null
    success "Task Definition '$TASK_DEF_COM_ALB' registrada."
  fi

  # 3. EC2 ECS Optimized (zona A e zona B)
  if ec2_existe "bia-ecs-alb-zona-a"; then
    skip "EC2 'bia-ecs-alb-zona-a'"
  else
    lancar_ec2_ecs "bia-ecs-alb-zona-a" "us-east-1a" "$SG_EC2" "$SUBNET_A" \
      "$INSTANCE_TYPE_COM_ALB" "$ECS_CLUSTER_COM_ALB" "$ECS_AMI"
  fi

  if ec2_existe "bia-ecs-alb-zona-b"; then
    skip "EC2 'bia-ecs-alb-zona-b'"
  else
    lancar_ec2_ecs "bia-ecs-alb-zona-b" "us-east-1b" "$SG_EC2" "$SUBNET_B" \
      "$INSTANCE_TYPE_COM_ALB" "$ECS_CLUSTER_COM_ALB" "$ECS_AMI"
  fi

  # 4. Service ECS com ALB
  if service_existe "$CLUSTER_COM_ALB" "$SERVICE_COM_ALB"; then
    skip "Service '$SERVICE_COM_ALB'"
  else
    info "Aguardando instâncias registrarem no cluster (30s)..."
    sleep 30

    info "Criando service '$SERVICE_COM_ALB'..."
    aws ecs create-service \
      --region "$AWS_REGION" \
      --cluster "$CLUSTER_COM_ALB" \
      --service-name "$SERVICE_COM_ALB" \
      --task-definition "$TASK_DEF_COM_ALB" \
      --desired-count 1 \
      --launch-type EC2 \
      --scheduling-strategy REPLICA \
      --deployment-controller type=ECS \
      --deployment-configuration "minimumHealthyPercent=0,maximumPercent=100" \
      --availability-zone-rebalancing DISABLED \
      --load-balancers "targetGroupArn=$TG_ARN,containerName=bia,containerPort=8080" \
      --health-check-grace-period-seconds 30 \
      --placement-strategy "type=spread,field=attribute:ecs.availability-zone" "type=spread,field=instanceId" \
      --output json > /dev/null
    success "Service '$SERVICE_COM_ALB' criado."
  fi

  ALB_DNS=$(aws elbv2 describe-load-balancers \
    --region "$AWS_REGION" \
    --names "bia-alb" \
    --query "LoadBalancers[0].DNSName" \
    --output text 2>/dev/null || echo "N/A")

  echo ""
  echo "┌──────────────────────────────────────────────────────┐"
  echo "│         ✅  Cenário 2 (Com ALB) Provisionado!        │"
  echo "├──────────────────────────────────────────────────────┤"
  printf "│  Cluster:   %-40s│\n" "$CLUSTER_COM_ALB"
  printf "│  Service:   %-40s│\n" "$SERVICE_COM_ALB"
  printf "│  Task Def:  %-40s│\n" "$TASK_DEF_COM_ALB"
  printf "│  ALB DNS:   %-40s│\n" "$ALB_DNS"
  echo "└──────────────────────────────────────────────────────┘"
}

# -----------------------------------------------------------------------------
# Menu Principal
# -----------------------------------------------------------------------------
clear
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║       🏗️   BIA - Provisionamento de Infraestrutura   ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║                                                      ║"
echo "║   1) Sem ALB  — cluster-bia + EC2 zona A             ║"
echo "║   2) Com ALB  — cluster-bia-alb + EC2 zona A e B     ║"
echo "║   3) Ambos    — provisiona os dois cenários           ║"
echo "║   4) Sair                                            ║"
echo "║                                                      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
read -rp "Opção [1-4]: " OPCAO

case "$OPCAO" in
  1) provisionar_sem_alb ;;
  2) provisionar_com_alb ;;
  3) provisionar_sem_alb; provisionar_com_alb ;;
  4) echo ""; info "Saindo..."; exit 0 ;;
  *) error "Opção inválida. Escolha entre 1 e 4." ;;
esac
