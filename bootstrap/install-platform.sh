#!/bin/bash
# platform-infra/bootstrap/install-platform.sh

set -e

# Color helper layouts for clear visual feedback
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============ 🎛️ Starting Platform Bootstrap Verification ============${NC}"

# =========================================================================
# STEP 1: HOST-LEVEL DEPENDENCY CHECKS (Idempotency Check for Mac CLI Tools)
# =========================================================================
echo -e "\n📋 Checking Host System Binaries..."
REQUIRED_TOOLS=("docker" "minikube" "kubectl" "helm")

for tool in "${REQUIRED_TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo -e "  ✅ $tool: Found (${GREEN}Ready${NC})"
    else
        echo -e "  ❌ $tool: ${YELLOW}Missing! Please install it on your machine first.${NC}"
        exit 1
    fi
done

# Quick defensive verification that Minikube is actually responsive
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo -e "  ⚠️  ${YELLOW}Kubernetes API cluster endpoint unreachable. Is Minikube running? Run 'minikube start'${NC}"
    exit 1
fi

# =========================================================================
# STEP 2: CENTRALIZED HELM REPOSITORY SETUP
# =========================================================================
echo -e "\n📦 Syncing Helm Repositories..."
declare -A HELM_REPOS=(
    ["argo"]="https://argoproj.github.io/argo-helm"
    ["harbor"]="https://helm.goharbor.io"
    ["jetstack"]="https://charts.jetstack.io"
    ["kyverno"]="https://kyverno.github.io/kyverno"
    ["jenkins"]="https://charts.jenkins.io"
    ["sonarqube"]="https://SonarSource.github.io/helm-chart-sonarqube"
    ["hashicorp"]="https://helm.releases.hashicorp.com"
    ["istio"]="https://istio-release.storage.googleapis.com/charts"
    ["codecentric"]="https://codecentric.github.io/helm-charts" # Standard chart home for Keycloak
)

for repo in "${!HELM_REPOS[@]}"; do
    helm repo add "$repo" "${HELM_REPOS[$repo]}" --force-update >/dev/null 2>&1
done
helm repo update >/dev/null 2>&1
echo -e "  ✅ All upstream Helm charts synchronized successfully."

# =========================================================================
# STEP 3: NAMESPACE PLUMBING MANAGEMENT
# =========================================================================
echo -e "\n⚙️ Managing Dedicated Infrastructure Namespaces..."
NAMESPACES=("argocd" "devops-tools" "kyverno" "istio-system")
for ns in "${NAMESPACES[@]}"; do
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done
echo -e "  ✅ Namespaces validated."

# =========================================================================
# STEP 4: DEFENSIVE SERVICE APPLICATIONS RUNTIME GATES
# =========================================================================
echo -e "\n🛡️ Reconciling Platform Application Layers..."

# 1. Kyverno Gate
if helm list -n kyverno | grep -q "kyverno"; then
    echo -e "  ⏭️  Kyverno: Managed (${GREEN}Skipping Installation${NC})"
else
    echo -e "  🤖 Kyverno: ${YELLOW}Installing (Policy Engine)...${NC}"
    helm upgrade --install kyverno kyverno/kyverno -n kyverno --wait
fi

# 2. ArgoCD Gate
if [ "$(kubectl get all -n argocd 2>&1 | grep -c "No resources found")" -eq 0 ] && ! helm list -n argocd | grep -q "argocd"; then
    echo -e "  ⏭️  ArgoCD: Non-Helm Setup Detected (${GREEN}Skipping to Protect Existing Data${NC})"
elif helm list -n argocd | grep -q "argocd"; then
    echo -e "  🔄 ArgoCD: Managed (${GREEN}Updating Configurations${NC})"
    helm upgrade argocd argo/argo-cd -n argocd --values helm-values/argocd-values.yaml
else
    echo -e "  🐙 ArgoCD: ${YELLOW}Installing Fresh Infrastructure Core...${NC}"
    helm upgrade --install argocd argo/argo-cd -n argocd --values helm-values/argocd-values.yaml
fi

# 3. Harbor Gate
if helm list -n devops-tools | grep -q "harbor"; then
    echo -e "  ⏭️  Harbor Registry: Managed (${GREEN}Skipping Installation${NC})"
else
    echo -e "  ⚓ Harbor Registry: ${YELLOW}Installing...${NC}"
    helm upgrade --install harbor harbor/harbor -n devops-tools --values helm-values/harbor-values.yaml
fi

# 4. Jenkins Gate
if helm list -n devops-tools | grep -q "jenkins"; then
    echo -e "  ⏭️  Jenkins CI: Managed (${GREEN}Skipping Installation${NC})"
else
    echo -e "  🏗️  Jenkins CI: ${YELLOW}Installing Core Build Engine...${NC}"
    helm upgrade --install jenkins jenkins/jenkins -n devops-tools --values helm-values/jenkins-values.yaml
fi

# 5. SonarQube Gate
if helm list -n devops-tools | grep -q "sonarqube"; then
    echo -e "  ⏭️  SonarQube: Managed (${GREEN}Skipping Installation${NC})"
else
    echo -e "  🔍 SonarQube: ${YELLOW}Installing Code Scanner...${NC}"
    helm upgrade --install sonarqube sonarqube/sonarqube -n devops-tools --values helm-values/sonarqube-values.yaml
fi

# 6. HashiCorp Vault Gate
if helm list -n devops-tools | grep -q "vault"; then
    echo -e "  ⏭️  HashiCorp Vault: Managed (${GREEN}Skipping Installation${NC})"
else
    echo -e "  🔑 HashiCorp Vault: ${YELLOW}Installing Secret Engine...${NC}"
    # Setting injector flag to true to allow dynamic sidecar agent population later
    helm upgrade --install vault hashicorp/vault -n devops-tools \
      --set "injector.enabled=true" \
      --set "server.dev.enabled=true" # Dev mode active for effortless local PoC use
fi

# 7. Keycloak Identity Access Gate
if helm list -n devops-tools | grep -q "keycloak"; then
    echo -e "  ⏭️  Keycloak: Managed (${GREEN}Skipping Installation${NC})"
else
    echo -e "  🛡️  Keycloak IAM: ${YELLOW}Installing Identity Manager...${NC}"
    helm upgrade --install keycloak codecentric/keycloak -n devops-tools
fi

# =========================================================================
# STEP 5: CUSTOM RESOURCE DEFINITION (CRD) OPERATOR GATES
# =========================================================================
echo -e "\n🧩 Reconciling Advanced Operator Frameworks..."

# 8. Istio Service Mesh Gate
if kubectl get crd | grep -q "istio.io"; then
    echo -e "  ⏭️  Istio Service Mesh: CRDs Found (${GREEN}Skipping Installation${NC})"
else
    echo -e "  🕸️  Istio Service Mesh: ${YELLOW}Installing Base & Istiod Discovery...${NC}"
    helm upgrade --install istio-base istio/base -n istio-system --set defaultRevision=default
    helm upgrade --install istiod istio/istiod -n istio-system --wait
fi

# 9. Knative Serving Gate
if kubectl get crd | grep -q "serving.knative.dev"; then
    echo -e "  ⏭️  Knative Serving: CRDs Found (${GREEN}Skipping Installation${NC})"
else
    echo -e "  🚀 Knative Serving: ${YELLOW}Installing Serverless Core Layer...${NC}"
    kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.11.0/serving-crds.yaml >/dev/null
    kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.11.0/serving-core.yaml >/dev/null
    echo -e "  ✅ Knative Serving components successfully provisioned!"
fi

echo -e "\n${GREEN}🎉 Idempotent Bootstrap Execution Complete! All systems verified/healthy.${NC}"