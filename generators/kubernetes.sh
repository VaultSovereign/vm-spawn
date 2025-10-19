#!/usr/bin/env bash
# kubernetes.sh - Generate Kubernetes manifests
# Usage: kubernetes.sh <repo-name>

set -euo pipefail

REPO_NAME="${1:-myapp}"

mkdir -p deployments/kubernetes/base
cat > deployments/kubernetes/base/deployment.yaml << 'K8S'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: APP_NAME
spec:
  replicas: 2
  selector:
    matchLabels:
      app: APP_NAME
  template:
    metadata:
      labels:
        app: APP_NAME
    spec:
      containers:
      - name: APP_NAME
        image: APP_NAME:latest
        ports:
        - containerPort: 8000
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: APP_NAME
spec:
  selector:
    app: APP_NAME
  ports:
  - port: 80
    targetPort: 8000
  type: ClusterIP
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: APP_NAME
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: APP_NAME
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
K8S

# Replace APP_NAME with actual name
sed -i.bak "s/APP_NAME/$REPO_NAME/g" deployments/kubernetes/base/deployment.yaml
rm -f deployments/kubernetes/base/deployment.yaml.bak

echo "✅ Kubernetes manifests"

