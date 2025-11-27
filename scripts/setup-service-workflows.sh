#!/bin/bash
# 为所有服务仓库配置工作流的脚本

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "配置服务仓库的 GitHub Actions 工作流"
echo "=========================================="
echo

# 服务列表
SERVICES=(
    "cedefi-api"
    "cedefi-order"
    "cedefi-job"
    "cedefi-evm-indexer"
    "cedefi-evm-trade"
    "cedefi-solana-indexer"
    "cedefi-solana-trade"
    "cedefi-solana-ticks"
    "cedefi-kline-compose"
    "cedefi-rpc"
)

WORKSPACE_ROOT="/home/apt69/cedefi-projects"
TEMPLATE_FILE="$WORKSPACE_ROOT/.github/workflow-templates/service-deploy.yml"

for service in "${SERVICES[@]}"; do
    SERVICE_DIR="$WORKSPACE_ROOT/$service"
    
    if [ ! -d "$SERVICE_DIR" ]; then
        echo -e "${YELLOW}⚠ 跳过: $service (目录不存在)${NC}"
        continue
    fi
    
    if [ ! -d "$SERVICE_DIR/.git" ]; then
        echo -e "${YELLOW}⚠ 跳过: $service (不是 Git 仓库)${NC}"
        continue
    fi
    
    echo "配置: $service"
    
    # 创建 .github/workflows 目录
    mkdir -p "$SERVICE_DIR/.github/workflows"
    
    # 复制并修改工作流文件
    WORKFLOW_FILE="$SERVICE_DIR/.github/workflows/deploy.yml"
    cp "$TEMPLATE_FILE" "$WORKFLOW_FILE"
    
    # 替换服务名
    sed -i "s/SERVICE_NAME_HERE/$service/g" "$WORKFLOW_FILE"
    
    echo -e "${GREEN}✓ 已创建: $WORKFLOW_FILE${NC}"
    
    # 检查是否需要配置 Secrets
    if [ -f "$SERVICE_DIR/.git/config" ]; then
        REPO_URL=$(git -C "$SERVICE_DIR" remote get-url origin 2>/dev/null || echo "")
        if [[ $REPO_URL == *"github.com"* ]]; then
            REPO_NAME=$(echo $REPO_URL | sed -E 's/.*github\.com[:/](.*)\.git/\1/')
            echo "  仓库: $REPO_NAME"
            echo "  需要配置 Secrets (继承自组织级或手动配置):"
            echo "    - GCP_PROJECT_ID"
            echo "    - GCP_SA_KEY"
            echo "    - GKE_CLUSTER_NAME"
            echo "    - GKE_REGION"
        fi
    fi
    
    echo
done

echo "=========================================="
echo -e "${GREEN}✓ 配置完成！${NC}"
echo "=========================================="
echo
echo "下一步操作："
echo "1. 检查各服务的 .github/workflows/deploy.yml 文件"
echo "2. 根据需要调整配置（Dockerfile 路径、k8s 配置等）"
echo "3. 提交并推送各服务仓库的更改"
echo "4. 确保各服务仓库有访问组织 Secrets 的权限"
echo
echo "配置组织级 Secrets（推荐）："
echo "gh secret set GCP_PROJECT_ID -b'cedefi-479416' --org cedefi-io --visibility all"
echo "gh secret set GKE_CLUSTER_NAME -b'cedefi-cluster-1' --org cedefi-io --visibility all"
echo "gh secret set GKE_REGION -b'asia-east1' --org cedefi-io --visibility all"
echo "gh secret set GCP_SA_KEY --org cedefi-io --visibility all < .github/scripts/gcp-key-20251127-140000.json"
echo
