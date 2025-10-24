#!/bin/bash
set -e

export PATH="/home/sovereign/google-cloud-sdk/bin:/snap/bin:/usr/bin:/bin"
export USE_GKE_GCLOUD_AUTH_PLUGIN=True

echo "=== Fixing KEDA Configuration ==="
echo ""

echo "1. Applying TriggerAuthentication for Workload Identity..."
kubectl apply -f /home/sovereign/vm-spawn/k8s/keda/trigger-auth.yaml
echo ""

echo "2. Deleting old ScaledObjects..."
kubectl delete scaledobject psi-field-scaler -n vaultmesh --ignore-not-found=true
kubectl delete scaledobject scheduler-scaler -n vaultmesh --ignore-not-found=true
echo ""

echo "3. Applying updated ScaledObjects..."
kubectl apply -f /home/sovereign/vm-spawn/k8s/keda/psi-field-scaler.yaml
kubectl apply -f /home/sovereign/vm-spawn/k8s/keda/scheduler-scaler.yaml
echo ""

echo "4. Waiting 10 seconds for KEDA to reconcile..."
sleep 10

echo "5. Checking ScaledObject status..."
kubectl get scaledobjects -n vaultmesh
echo ""

echo "6. Checking HPA status..."
kubectl get hpa -n vaultmesh
echo ""

echo "7. Checking deployments..."
kubectl get deployments -n vaultmesh
echo ""

echo "✅ KEDA configuration updated!"
echo ""
echo "The services should now be at 0/0 replicas (scale-to-zero)."
echo ""
