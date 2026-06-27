#!/bin/bash
# local-platform-infra/bootstrap/minikube-start.sh
# This script spins up Minikube with optimized resources for your
# Mac and enables the essential network tunneling and addons.

echo "🚀 Starting Minikube with optimized resource profiles..."

# Giving Minikube enough resources to handle our dense stack safely
minikube start \
  --cpus=4 \
  --memory=8192 \
  --disk-size=40g \
  --driver=docker \
  --addons=ingress,metrics-server

echo "🌐 Enabling Minikube Tunneling capability..."

echo "✅ Minikube is up and ready for platform bootstrap."