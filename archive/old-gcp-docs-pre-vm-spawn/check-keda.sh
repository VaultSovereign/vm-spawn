#!/bin/bash

export PATH="/home/sovereign/google-cloud-sdk/bin:/snap/bin:/usr/bin:/bin"
export USE_GKE_GCLOUD_AUTH_PLUGIN=True

echo "=== Checking KEDA ScaledObject Status ==="
echo ""

echo "1. PSI-Field ScaledObject:"
kubectl describe scaledobject psi-field-scaler -n vaultmesh > /tmp/psi-field-scaler.txt 2>&1
cat /tmp/psi-field-scaler.txt | tail -50
echo ""

echo "2. Scheduler ScaledObject:"
kubectl describe scaledobject scheduler-scaler -n vaultmesh > /tmp/scheduler-scaler.txt 2>&1
cat /tmp/scheduler-scaler.txt | tail -50
echo ""

echo "3. KEDA Operator Logs:"
kubectl logs -n keda deployment/keda-operator --tail=20 > /tmp/keda-operator-logs.txt 2>&1
cat /tmp/keda-operator-logs.txt
echo ""

echo "4. Check if secret exists:"
kubectl get secret vaultmesh-pubsub-secret -n vaultmesh -o yaml | grep -E "(name|namespace)" | head -5
echo ""

echo "5. HPA Status:"
kubectl get hpa -n vaultmesh
echo ""
