#!/bin/bash
set -e

echo "Waiting for LoadBalancer IP assignment..."
for i in {1..20}; do
    echo "Check $i/20..."
    INGRESS_IP=$(kubectl get ingress vaultmesh-ingress -n vaultmesh -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

    if [ -n "$INGRESS_IP" ]; then
        echo "✓ LoadBalancer IP assigned: $INGRESS_IP"
        exit 0
    else
        echo "  Still provisioning..."
        sleep 15
    fi
done

echo "⚠ LoadBalancer still provisioning after 5 minutes. You may need to wait longer."
echo "Check status with: kubectl get ingress vaultmesh-ingress -n vaultmesh"
