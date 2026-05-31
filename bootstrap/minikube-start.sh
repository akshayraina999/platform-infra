#!/bin/bash
# local-platform-infra/bootstrap/minikube-start.sh
# This script spins up Minikube with optimized resources for your
# Mac and enables the essential network tunneling and addons.

echo "🚀 Starting Minikube with optimized resource profiles..."

# Giving Minikube enough resources to handle our dense stack safely
minikube start \
  --cpus=4 \
  --memory=12288 \
  --disk-size=40g \
  --driver=docker \
  --addons=ingress,metrics-server

echo "🌐 Enabling Minikube Tunneling capability..."
echo "Please keep this script or a separate terminal running 'minikube tunnel' to map LoadBalancers."
# Running tunnel in background so it assigns IPs to our Ingress/Istio Gateways
sudo -b minikube tunnel

echo "✅ Minikube is up and ready for platform bootstrap."