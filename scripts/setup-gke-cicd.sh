#!/bin/bash
# GKE CI/CD 快速配置脚本

set -e

echo "=========================================="
echo "GKE CI/CD 配置脚本"
echo "=========================================="
echo

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查必要的工具
check_tools() {
    echo "检查必要工具..."
    
    if ! command -v gcloud &> /dev/null; then
        echo -e "${RED}错误: gcloud CLI 未安装${NC}"
        echo "请访问: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}错误: kubectl 未安装${NC}"
        echo "请访问: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    
    echo -e "${GREEN}✓ 所有工具已安装${NC}"
    echo
}

# 输入配置信息
read_config() {
    echo "请输入 GCP 配置信息:"
    echo
    
    read -p "GCP Project ID: " PROJECT_ID
    read -p "GKE Cluster Name: " CLUSTER_NAME
    read -p "GKE Zone (例如: us-central1-a): " ZONE
    read -p "Service Account Name (默认: github-actions-sa): " SA_NAME
    SA_NAME=${SA_NAME:-github-actions-sa}
    
    echo
    echo "配置信息:"
    echo "- Project ID: $PROJECT_ID"
    echo "- Cluster Name: $CLUSTER_NAME"
    echo "- Zone: $ZONE"
    echo "- Service Account: $SA_NAME"
    echo
    
    read -p "确认配置正确? (y/n): " confirm
    if [[ $confirm != "y" ]]; then
        echo "已取消"
        exit 0
    fi
}

# 创建服务账号
create_service_account() {
    echo
    echo "=========================================="
    echo "1. 创建 GCP 服务账号"
    echo "=========================================="
    
    SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
    
    # 检查服务账号是否已存在
    if gcloud iam service-accounts describe $SA_EMAIL --project=$PROJECT_ID &> /dev/null; then
        echo -e "${YELLOW}⚠ 服务账号已存在: $SA_EMAIL${NC}"
    else
        echo "创建服务账号: $SA_EMAIL"
        gcloud iam service-accounts create $SA_NAME \
            --display-name="GitHub Actions Service Account" \
            --project=$PROJECT_ID
        echo -e "${GREEN}✓ 服务账号创建成功${NC}"
    fi
}

# 授予权限
grant_permissions() {
    echo
    echo "=========================================="
    echo "2. 授予 IAM 权限"
    echo "=========================================="
    
    SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
    
    ROLES=(
        "roles/container.developer"
        "roles/storage.admin"
        "roles/iam.serviceAccountUser"
    )
    
    for role in "${ROLES[@]}"; do
        echo "授予权限: $role"
        gcloud projects add-iam-policy-binding $PROJECT_ID \
            --member="serviceAccount:$SA_EMAIL" \
            --role="$role" \
            --quiet
    done
    
    echo -e "${GREEN}✓ 权限授予成功${NC}"
}

# 生成密钥
generate_key() {
    echo
    echo "=========================================="
    echo "3. 生成服务账号密钥"
    echo "=========================================="
    
    SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
    KEY_FILE="gcp-key-$(date +%Y%m%d-%H%M%S).json"
    
    gcloud iam service-accounts keys create $KEY_FILE \
        --iam-account=$SA_EMAIL \
        --project=$PROJECT_ID
    
    echo -e "${GREEN}✓ 密钥文件已生成: $KEY_FILE${NC}"
    echo
    echo -e "${YELLOW}重要: 请将此文件内容复制到 GitHub Secrets${NC}"
    echo "1. 打开 GitHub 仓库"
    echo "2. 进入 Settings → Secrets and variables → Actions"
    echo "3. 点击 'New repository secret'"
    echo "4. Name: GCP_SA_KEY"
    echo "5. Value: $(cat $KEY_FILE)"
    echo
}

# 配置 GitHub Secrets
configure_github_secrets() {
    echo
    echo "=========================================="
    echo "4. GitHub Secrets 配置"
    echo "=========================================="
    echo
    echo "请在 GitHub 仓库中配置以下 Secrets:"
    echo
    echo -e "${YELLOW}名称: GCP_SA_KEY${NC}"
    echo "值: (上面生成的密钥文件内容)"
    echo
    echo -e "${YELLOW}名称: GCP_PROJECT_ID${NC}"
    echo "值: $PROJECT_ID"
    echo
    echo -e "${YELLOW}名称: GKE_CLUSTER_NAME${NC}"
    echo "值: $CLUSTER_NAME"
    echo
    echo -e "${YELLOW}名称: GKE_ZONE${NC}"
    echo "值: $ZONE"
    echo
}

# 创建 Kubernetes Namespaces
create_namespaces() {
    echo
    echo "=========================================="
    echo "5. 创建 Kubernetes Namespaces"
    echo "=========================================="
    
    # 获取 GKE 凭证
    echo "获取 GKE 集群凭证..."
    gcloud container clusters get-credentials $CLUSTER_NAME \
        --zone $ZONE \
        --project $PROJECT_ID
    
    # 创建 namespaces
    NAMESPACES=("cedefi-dev" "cedefi-test" "cedefi-prod")
    
    for ns in "${NAMESPACES[@]}"; do
        if kubectl get namespace $ns &> /dev/null; then
            echo -e "${YELLOW}⚠ Namespace 已存在: $ns${NC}"
        else
            echo "创建 namespace: $ns"
            kubectl create namespace $ns
            echo -e "${GREEN}✓ Namespace 创建成功: $ns${NC}"
        fi
    done
}

# 验证配置
verify_setup() {
    echo
    echo "=========================================="
    echo "6. 验证配置"
    echo "=========================================="
    
    echo "检查服务账号..."
    gcloud iam service-accounts describe ${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
        --project=$PROJECT_ID > /dev/null 2>&1 && echo -e "${GREEN}✓ 服务账号存在${NC}"
    
    echo "检查 GKE 集群..."
    gcloud container clusters describe $CLUSTER_NAME \
        --zone $ZONE \
        --project $PROJECT_ID > /dev/null 2>&1 && echo -e "${GREEN}✓ GKE 集群可访问${NC}"
    
    echo "检查 Kubernetes namespaces..."
    kubectl get namespaces cedefi-dev cedefi-test cedefi-prod > /dev/null 2>&1 && \
        echo -e "${GREEN}✓ Namespaces 已创建${NC}"
}

# 主流程
main() {
    check_tools
    read_config
    create_service_account
    grant_permissions
    generate_key
    configure_github_secrets
    create_namespaces
    verify_setup
    
    echo
    echo "=========================================="
    echo -e "${GREEN}✓ 配置完成!${NC}"
    echo "=========================================="
    echo
    echo "下一步:"
    echo "1. 将生成的密钥配置到 GitHub Secrets"
    echo "2. 推送代码到 main 或 dev 分支触发部署"
    echo "3. 或在 Actions 页面手动触发 workflow"
    echo
    echo "文档: .github/CICD_DEPLOYMENT_GUIDE.md"
    echo
}

# 运行主流程
main
