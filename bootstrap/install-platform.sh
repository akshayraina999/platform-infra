#!/bin/bash
# local-platform-infra/bootstrap/install-platform.sh
# This orchestrator script installs Helm charts sequentially. 
# We use Helm dependencies or raw Helm commands to manage our core stack tools.

set -e

echo "📦 Adding Helm Repositories..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add harbor https://helm.goharbor.io
helm repo add jetstack https://charts.jetstack.io
helm repo add kyverno https://kyverno.github.io/kyverno
helm repo update

echo "⚙️ Creating Namespaces..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace devops-tools --dry-run=client -o yaml | kubectl apply -f - # For Jenkins/SonarQube/Harbor/Keycloak
kubectl create namespace kyverno --dry-run=client -o yaml | kubectl apply -f -

echo "🤖 Installing Kyverno (Policy Engine)..."
helm upgrade --install kyverno kyverno/kyverno -n kyverno

echo "🐙 Installing ArgoCD..."
helm upgrade --install argocd argo/argo-cd -n argocd --values ../helm-values/argocd-values.yaml

echo "⚓ Installing Harbor Registry..."
helm upgrade --install harbor harbor/harbor -n devops-tools --values ../helm-values/harbor-values.yaml

echo "🎉 Base control plane components applied!"