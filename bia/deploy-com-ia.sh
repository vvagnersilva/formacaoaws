#!/bin/bash

# =============================================================================
# Script de Deploy e Rollback - Projeto BIA
# =============================================================================
# Uso:
#   ./scripts/deploy.sh
#
# Fluxo de Deploy:
#   1. Informa o short commit hash e escolhe o ambiente
#   2. Faz build da imagem Docker localmente
#   3. Faz push para ECR com tag = commit hash
#   4. Cria nova revisão da Task Definition
#   5. Atualiza o ECS Service
#   6. Aguarda estabilização
#
# Fluxo de Rollback:
#   1. Escolhe o ambiente
#   2. Lista as últimas 10 revisões da Task Definition
#   3. Escolhe a revisão desejada
#   4. Atualiza o ECS Service
#   5. Aguarda estabilização
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Configurações
# -----------------------------------------------------------------------------
AWS_REGION="us-east-1"
ECR_REGISTRY="455958489218.dkr.ecr.us-east-1.amazonaws.com"
ECR_REPO="bia"
REPOSITORY_URI="$ECR_REGISTRY/$ECR_REPO"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Configurações por ambiente
CLUSTER_SEM_ALB="cluster-bia"
CLUSTER_COM_ALB="cluster-bia-alb"
TASK_DEF_SEM_ALB="task-def-bia"
TASK_DEF_COM_ALB="task-def-bia-alb"
SERVICE_SEM_ALB="service-bia"
SERVICE_COM_ALB="service-bia-alb"

# -----------------------------------------------------------------------------
# Funções auxiliares
# -----------------------------------------------------------------------------
info()    { echo -e "\n\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\n\033[1;32m[OK]\033[0m $1"; }
error()   { echo -e "\n\033[1;31m[ERRO]\033[0m $1" >&2; exit 1; }
warn()    { echo -e "\n\033[1;33m[AVISO]\033[0m $1"; }

aguardar_estabilizacao() {
  local cluster=$1
  local service=$2

  info "Aguardando estabilização do serviço '$service' no cluster '$cluster'..."
  info "Isso pode levar alguns minutos..."

  aws ecs wait services-stable \
    --region "$AWS_REGION" \
    --cluster "$cluster" \
    --services "$service"

  success "Serviço estabilizado com sucesso!"
}

escolher_ambiente() {
  echo ""
  echo "┌─────────────────────────────┐"
  echo "│      Escolha o ambiente     │"
  echo "├─────────────────────────────┤"
  echo "│  1) Sem ALB                 │"
  echo "│  2) Com ALB                 │"
  echo "└─────────────────────────────┘"
  echo ""
  read -rp "Opção [1-2]: " opcao_ambiente

  case "$opcao_ambiente" in
    1)
      CLUSTER="$CLUSTER_SEM_ALB"
      TASK_DEF="$TASK_DEF_SEM_ALB"
      SERVICE="$SERVICE_SEM_ALB"
      AMBIENTE_LABEL="Sem ALB"
      ;;
    2)
      CLUSTER="$CLUSTER_COM_ALB"
      TASK_DEF="$TASK_DEF_COM_ALB"
      SERVICE="$SERVICE_COM_ALB"
      AMBIENTE_LABEL="Com ALB"
      ;;
    *)
      error "Opção inválida. Escolha 1 ou 2."
      ;;
  esac

  success "Ambiente selecionado: $AMBIENTE_LABEL"
  info "  Cluster:         $CLUSTER"
  info "  Task Definition: $TASK_DEF"
  info "  Service:         $SERVICE"
}

# -----------------------------------------------------------------------------
# Fluxo de Deploy
# -----------------------------------------------------------------------------
executar_deploy() {
  info "=== FLUXO DE DEPLOY ==="

  # 1. Capturar os 7 primeiros dígitos do commit hash do repositório Git local
  info "Capturando commit hash do repositório Git local..."

  if ! git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
    error "O diretório '$PROJECT_DIR' não é um repositório Git."
  fi

  COMMIT_HASH=$(git -C "$PROJECT_DIR" rev-parse --short=7 HEAD)

  if [[ -z "$COMMIT_HASH" ]]; then
    error "Não foi possível obter o commit hash do repositório Git."
  fi

  success "Commit hash capturado: $COMMIT_HASH"

  IMAGE_TAG="$COMMIT_HASH"
  IMAGE_URI="$REPOSITORY_URI:$IMAGE_TAG"

  # 2. Escolher ambiente
  escolher_ambiente

  echo ""
  echo "┌──────────────────────────────────────────────────────┐"
  echo "│                  Resumo do Deploy                    │"
  echo "├──────────────────────────────────────────────────────┤"
  printf "│  Commit Hash:  %-37s│\n" "$COMMIT_HASH"
  printf "│  Imagem:       %-37s│\n" "$IMAGE_URI"
  printf "│  Ambiente:     %-37s│\n" "$AMBIENTE_LABEL"
  printf "│  Cluster:      %-37s│\n" "$CLUSTER"
  printf "│  Service:      %-37s│\n" "$SERVICE"
  echo "└──────────────────────────────────────────────────────┘"
  echo ""
  read -rp "Confirmar deploy? [s/N]: " confirmacao

  if [[ ! "$confirmacao" =~ ^[sS]$ ]]; then
    warn "Deploy cancelado pelo usuário."
    exit 0
  fi

  # 3. Build da imagem Docker
  info "Fazendo build da imagem Docker..."
  cd "$PROJECT_DIR"
  docker build -t "$REPOSITORY_URI:latest" .
  docker tag "$REPOSITORY_URI:latest" "$IMAGE_URI"
  success "Build concluído: $IMAGE_URI"

  # 4. Login no ECR e push da imagem
  info "Fazendo login no ECR..."
  aws ecr get-login-password --region "$AWS_REGION" \
    | docker login --username AWS --password-stdin "$ECR_REGISTRY"

  info "Fazendo push da imagem para o ECR..."
  docker push "$REPOSITORY_URI:latest"
  docker push "$IMAGE_URI"
  success "Push concluído!"

  # 5. Criar nova revisão da Task Definition
  info "Buscando Task Definition atual: $TASK_DEF..."

  # Verifica se a task definition já existe; se não, usa task-def-bia como base
  if aws ecs describe-task-definition \
      --region "$AWS_REGION" \
      --task-definition "$TASK_DEF" \
      --query "taskDefinition" \
      --output json &>/dev/null 2>&1; then
    TASK_DEF_JSON=$(aws ecs describe-task-definition \
      --region "$AWS_REGION" \
      --task-definition "$TASK_DEF" \
      --query "taskDefinition" \
      --output json)
    info "Task Definition '$TASK_DEF' encontrada. Usando como base."
  else
    warn "Task Definition '$TASK_DEF' não encontrada. Usando 'task-def-bia' como base e criando '$TASK_DEF'."
    TASK_DEF_JSON=$(aws ecs describe-task-definition \
      --region "$AWS_REGION" \
      --task-definition "task-def-bia" \
      --query "taskDefinition" \
      --output json)
  fi

  # Atualizar a imageUri na definição do container
  NOVO_TASK_DEF_JSON=$(echo "$TASK_DEF_JSON" | \
    python3 -c "
import json, sys
td = json.load(sys.stdin)
# Garantir que o family é o correto (pode ser diferente se usamos task-def-bia como base)
td['family'] = '$TASK_DEF'
for c in td['containerDefinitions']:
    c['image'] = '$IMAGE_URI'
# Remover campos que não são aceitos no register
for campo in ['taskDefinitionArn','revision','status','requiresAttributes','compatibilities','registeredAt','registeredBy']:
    td.pop(campo, None)
print(json.dumps(td))
")

  info "Registrando nova revisão da Task Definition..."
  NOVA_REVISAO=$(aws ecs register-task-definition \
    --region "$AWS_REGION" \
    --cli-input-json "$NOVO_TASK_DEF_JSON" \
    --query "taskDefinition.taskDefinitionArn" \
    --output text)

  success "Nova revisão registrada: $NOVA_REVISAO"

  # 6. Atualizar o ECS Service
  info "Atualizando o service '$SERVICE' para a nova revisão..."
  aws ecs update-service \
    --region "$AWS_REGION" \
    --cluster "$CLUSTER" \
    --service "$SERVICE" \
    --task-definition "$NOVA_REVISAO" \
    --deployment-configuration "minimumHealthyPercent=0,maximumPercent=100" \
    --output json > /dev/null

  success "Service atualizado!"

  # 7. Aguardar estabilização
  aguardar_estabilizacao "$CLUSTER" "$SERVICE"

  echo ""
  echo "┌──────────────────────────────────────────────────────┐"
  echo "│              ✅  Deploy Concluído!                   │"
  echo "├──────────────────────────────────────────────────────┤"
  printf "│  Imagem:    %-40s│\n" "$IMAGE_URI"
  printf "│  Revisão:   %-40s│\n" "$(echo "$NOVA_REVISAO" | awk -F: '{print $NF}')"
  printf "│  Ambiente:  %-40s│\n" "$AMBIENTE_LABEL"
  echo "└──────────────────────────────────────────────────────┘"
}

# -----------------------------------------------------------------------------
# Fluxo de Rollback
# -----------------------------------------------------------------------------
executar_rollback() {
  info "=== FLUXO DE ROLLBACK ==="

  # 1. Escolher ambiente
  escolher_ambiente

  # 2. Listar as últimas 10 revisões
  info "Buscando as últimas 10 revisões da Task Definition '$TASK_DEF'..."

  REVISOES=$(aws ecs list-task-definitions \
    --region "$AWS_REGION" \
    --family-prefix "$TASK_DEF" \
    --sort DESC \
    --max-items 10 \
    --query "taskDefinitionArns[]" \
    --output json)

  if [[ "$REVISOES" == "[]" || -z "$REVISOES" ]]; then
    error "Nenhuma revisão encontrada para a Task Definition '$TASK_DEF'."
  fi

  # Exibir tabela de revisões
  echo ""
  echo "┌─────┬──────────────┬──────────────────────────────────────────────────────┐"
  printf "│ %-3s │ %-12s │ %-52s │\n" "#" "Revisão" "Imagem (tag)"
  echo "├─────┼──────────────┼──────────────────────────────────────────────────────┤"

  ARNS=()
  INDEX=0
  while IFS= read -r ARN; do
    ARN=$(echo "$ARN" | tr -d '",' | xargs)
    [[ -z "$ARN" ]] && continue

    ARNS+=("$ARN")
    REVISAO_NUM=$(echo "$ARN" | awk -F: '{print $NF}')

    # Buscar imagem da task definition
    IMAGEM=$(aws ecs describe-task-definition \
      --region "$AWS_REGION" \
      --task-definition "$ARN" \
      --query "taskDefinition.containerDefinitions[0].image" \
      --output text 2>/dev/null || echo "N/A")

    # Extrair apenas a tag da imagem para exibição
    TAG=$(echo "$IMAGEM" | awk -F: '{print $NF}')

    INDEX=$((INDEX + 1))
    printf "│ %-3s │ %-12s │ %-52s │\n" "$INDEX" "$REVISAO_NUM" "$TAG"
  done < <(echo "$REVISOES" | python3 -c "import json,sys; [print(x) for x in json.load(sys.stdin)]")

  echo "└─────┴──────────────┴──────────────────────────────────────────────────────┘"

  if [[ ${#ARNS[@]} -eq 0 ]]; then
    error "Não foi possível processar as revisões."
  fi

  # 3. Escolher revisão
  echo ""
  read -rp "Escolha o número da revisão para rollback [1-${#ARNS[@]}]: " ESCOLHA

  if ! [[ "$ESCOLHA" =~ ^[0-9]+$ ]] || [[ "$ESCOLHA" -lt 1 ]] || [[ "$ESCOLHA" -gt ${#ARNS[@]} ]]; then
    error "Opção inválida. Escolha um número entre 1 e ${#ARNS[@]}."
  fi

  ARN_ESCOLHIDO="${ARNS[$((ESCOLHA - 1))]}"
  REVISAO_ESCOLHIDA=$(echo "$ARN_ESCOLHIDO" | awk -F: '{print $NF}')

  echo ""
  echo "┌──────────────────────────────────────────────────────┐"
  echo "│                 Resumo do Rollback                   │"
  echo "├──────────────────────────────────────────────────────┤"
  printf "│  Ambiente:  %-40s│\n" "$AMBIENTE_LABEL"
  printf "│  Cluster:   %-40s│\n" "$CLUSTER"
  printf "│  Service:   %-40s│\n" "$SERVICE"
  printf "│  Revisão:   %-40s│\n" "$REVISAO_ESCOLHIDA"
  echo "└──────────────────────────────────────────────────────┘"
  echo ""
  read -rp "Confirmar rollback? [s/N]: " confirmacao

  if [[ ! "$confirmacao" =~ ^[sS]$ ]]; then
    warn "Rollback cancelado pelo usuário."
    exit 0
  fi

  # 4. Atualizar o ECS Service
  info "Atualizando o service '$SERVICE' para a revisão $REVISAO_ESCOLHIDA..."
  aws ecs update-service \
    --region "$AWS_REGION" \
    --cluster "$CLUSTER" \
    --service "$SERVICE" \
    --task-definition "$ARN_ESCOLHIDO" \
    --deployment-configuration "minimumHealthyPercent=0,maximumPercent=100" \
    --output json > /dev/null

  success "Service atualizado!"

  # 5. Aguardar estabilização
  aguardar_estabilizacao "$CLUSTER" "$SERVICE"

  echo ""
  echo "┌──────────────────────────────────────────────────────┐"
  echo "│              ✅  Rollback Concluído!                 │"
  echo "├──────────────────────────────────────────────────────┤"
  printf "│  Revisão:   %-40s│\n" "$REVISAO_ESCOLHIDA"
  printf "│  Ambiente:  %-40s│\n" "$AMBIENTE_LABEL"
  echo "└──────────────────────────────────────────────────────┘"
}

# -----------------------------------------------------------------------------
# Menu Principal
# -----------------------------------------------------------------------------
clear
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║          🚀  BIA - Deploy & Rollback ECS             ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║                                                      ║"
echo "║   1) Deploy    — Build, push e atualizar serviço     ║"
echo "║   2) Rollback  — Voltar para uma revisão anterior    ║"
echo "║   3) Sair                                            ║"
echo "║                                                      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
read -rp "Opção [1-3]: " OPCAO_PRINCIPAL

case "$OPCAO_PRINCIPAL" in
  1) executar_deploy ;;
  2) executar_rollback ;;
  3) echo ""; info "Saindo..."; exit 0 ;;
  *) error "Opção inválida. Escolha 1, 2 ou 3." ;;
esac
