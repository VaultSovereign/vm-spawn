# 🌟 Aurora Deployment Status — EKS Production

**Cluster:** aurora-staging (eu-west-1)  
**Status:** ✅ OPERATIONAL  
**Uptime:** 19+ hours  
**Last Verified:** 2025-01-XX

---

## 📊 Current Deployment Overview

### EKS Cluster
- **Name:** aurora-staging
- **Region:** eu-west-1
- **Endpoint:** `1C1822F8DB52C86A7193B5B4E2DC3524.gr7.eu-west-1.eks.amazonaws.com`
- **Nodes:** 3 active (m6i.large)

### Namespace: aurora-staging

**Running Services (7):**
1. ✅ **aurora-metrics-exporter** — Prometheus metrics (ClusterIP:9109)
2. ✅ **grafana** — Visualization (LoadBalancer:80)
3. ✅ **prometheus-server** — Metrics storage (LoadBalancer:80)
4. ✅ **ollama-cpu** — LLM inference (ClusterIP:11434)
5. ✅ **prometheus-kube-state-metrics** — K8s metrics (ClusterIP:8080)
6. ✅ **prometheus-node-exporter** — Node metrics (ClusterIP:9100)
7. ✅ **prometheus-pushgateway** — Batch metrics (ClusterIP:9091)

**Running Pods (12):**
- ✅ aurora-metrics-exporter (1/1 Running)
- ✅ grafana (1/1 Running)
- ✅ ollama-cpu (1/1 Running)
- ✅ prometheus-server (2/2 Running)
- ✅ prometheus-kube-state-metrics (1/1 Running)
- ✅ prometheus-node-exporter (3/3 Running - DaemonSet)
- ✅ prometheus-pushgateway (1/1 Running)
- ✅ soak-heartbeat (CronJob - 3 completed runs)

**Ingresses (1):**
- ✅ ollama-cpu-ing → `ollama.vaultmesh.cloud`

---

## 🎯 P0 Tasks — Deploy to Existing Infrastructure

### Task 1: Deploy Ψ-Field (30 minutes)

**Current Status:** ❌ Not deployed  
**Target:** Deploy to aurora-staging namespace

```bash
# 1. Deploy Ψ-Field service
kubectl -n aurora-staging apply -f services/psi-field/k8s/deployment.yaml

# 2. Verify deployment
kubectl -n aurora-staging get pods -l app=psi-field
kubectl -n aurora-staging logs -l app=psi-field --tail=50

# 3. Wire Prometheus scraping
kubectl -n aurora-staging apply -f services/psi-field/k8s/monitoring/servicemonitor.yaml

# 4. Add HPA for autoscaling
kubectl -n aurora-staging apply -f services/psi-field/k8s/monitoring/hpa.yaml

# 5. Verify metrics endpoint
kubectl -n aurora-staging port-forward svc/psi-field 8001:8001 &
curl http://localhost:8001/metrics | grep psi_field
```

**Expected Result:**
- Pod: `psi-field-xxx` (1/1 Running)
- Service: `psi-field` (ClusterIP:8001)
- Metrics: Visible in Prometheus

---

### Task 2: Deploy Harbinger (30 minutes)

**Current Status:** ❌ Not deployed  
**Target:** Deploy to aurora-staging namespace

```bash
# 1. Build and test locally first
cd services/harbinger
npm install ajv ajv-formats express pino prom-client
npm install -D ts-node jest ts-jest supertest @types/express @types/jest @types/supertest
npm test

# 2. Build Docker image (if needed)
docker build -t harbinger:latest .

# 3. Deploy to EKS
kubectl -n aurora-staging apply -f services/harbinger/k8s/

# 4. Verify deployment
kubectl -n aurora-staging get pods -l app=harbinger
kubectl -n aurora-staging logs -l app=harbinger --tail=50

# 5. Test health endpoint
kubectl -n aurora-staging port-forward svc/harbinger 8081:8081 &
curl http://localhost:8081/health
curl http://localhost:8081/metrics
```

**Expected Result:**
- Pod: `harbinger-xxx` (1/1 Running)
- Service: `harbinger` (ClusterIP:8081)
- Health: `/health` returns 200
- Metrics: `/metrics` exposes validation counters

---

### Task 3: Import Grafana Dashboards (15 minutes)

**Current Status:** Grafana running at LoadBalancer  
**Target:** Add 3 VaultMesh dashboards

```bash
# 1. Get Grafana LoadBalancer URL
GRAFANA_URL=$(kubectl -n aurora-staging get svc grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Grafana: http://$GRAFANA_URL"

# 2. Get Grafana admin password
GRAFANA_PASSWORD=$(kubectl -n aurora-staging get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d)
echo "Password: $GRAFANA_PASSWORD"

# 3. Option A: Manual import via UI
# - Open http://$GRAFANA_URL
# - Login: admin / $GRAFANA_PASSWORD
# - Navigate: Dashboards → Import
# - Upload: ops/grafana/dashboards/*.json

# 4. Option B: Automated via ConfigMap
kubectl -n aurora-staging create configmap vm-grafana-dashboards \
  --from-file=ops/grafana/dashboards/psi-field-dashboard.json \
  --from-file=ops/grafana/dashboards/scheduler-dashboard.json \
  --from-file=ops/grafana/dashboards/aurora-kpis-dashboard.json \
  --dry-run=client -o yaml | kubectl apply -f -

# 5. Verify dashboards
# Open Grafana → Dashboards → Browse
# Should see: "Ψ-Field Consciousness", "Scheduler Anchoring", "Aurora KPIs"
```

**Expected Result:**
- 3 dashboards visible in Grafana
- Ψ-Field dashboard shows metrics (once Ψ-Field is deployed)
- Scheduler dashboard shows anchor metrics
- Aurora dashboard shows KPIs

---

## 🔍 Current Monitoring Stack

### Prometheus
- **Service:** prometheus-server (LoadBalancer)
- **Port:** 80
- **Status:** ✅ Running (2/2 pods)
- **Scrape Targets:** 
  - aurora-metrics-exporter (9109)
  - kube-state-metrics (8080)
  - node-exporter (9100)
  - pushgateway (9091)

**Access Prometheus:**
```bash
# Get LoadBalancer URL
PROM_URL=$(kubectl -n aurora-staging get svc prometheus-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Prometheus: http://$PROM_URL"

# Or port-forward
kubectl -n aurora-staging port-forward svc/prometheus-server 9090:80 &
open http://localhost:9090
```

### Grafana
- **Service:** grafana (LoadBalancer)
- **Port:** 80
- **Status:** ✅ Running (1/1 pod)
- **Default Login:** admin / [from secret]

**Access Grafana:**
```bash
# Get LoadBalancer URL
GRAFANA_URL=$(kubectl -n aurora-staging get svc grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Grafana: http://$GRAFANA_URL"

# Get password
GRAFANA_PASSWORD=$(kubectl -n aurora-staging get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d)
echo "Password: $GRAFANA_PASSWORD"

# Open browser
open "http://$GRAFANA_URL"
```

### Aurora Metrics Exporter
- **Service:** aurora-metrics-exporter (ClusterIP)
- **Port:** 9109
- **Status:** ✅ Running (1/1 pod)
- **Purpose:** Exports Aurora-specific metrics to Prometheus

**Verify Metrics:**
```bash
kubectl -n aurora-staging port-forward svc/aurora-metrics-exporter 9109:9109 &
curl http://localhost:9109/metrics | grep aurora_
```

---

## 🚀 Quick Deployment Commands (All P0 Tasks)

```bash
# Set context
kubectl config use-context arn:aws:eks:eu-west-1:509399262563:cluster/aurora-staging

# Deploy Ψ-Field
kubectl -n aurora-staging apply -f services/psi-field/k8s/deployment.yaml
kubectl -n aurora-staging apply -f services/psi-field/k8s/monitoring/servicemonitor.yaml
kubectl -n aurora-staging apply -f services/psi-field/k8s/monitoring/hpa.yaml

# Deploy Harbinger (after local build/test)
cd services/harbinger && npm install && npm test && cd ../..
kubectl -n aurora-staging apply -f services/harbinger/k8s/

# Import Grafana dashboards
kubectl -n aurora-staging create configmap vm-grafana-dashboards \
  --from-file=ops/grafana/dashboards/ \
  --dry-run=client -o yaml | kubectl apply -f -

# Verify all deployments
kubectl -n aurora-staging get pods -l 'app in (psi-field,harbinger)'
```

---

## 📊 Verification Checklist

### Ψ-Field
- [ ] Pod running: `kubectl -n aurora-staging get pods -l app=psi-field`
- [ ] Metrics endpoint: `curl http://psi-field:8001/metrics`
- [ ] Prometheus scraping: Check Prometheus UI → Targets
- [ ] Grafana dashboard: "Ψ-Field Consciousness" shows data

### Harbinger
- [ ] Pod running: `kubectl -n aurora-staging get pods -l app=harbinger`
- [ ] Health endpoint: `curl http://harbinger:8081/health`
- [ ] Metrics endpoint: `curl http://harbinger:8081/metrics`
- [ ] Tests passing: `cd services/harbinger && npm test`

### Grafana Dashboards
- [ ] 3 dashboards imported
- [ ] Ψ-Field dashboard shows metrics
- [ ] Scheduler dashboard shows metrics
- [ ] Aurora KPIs dashboard shows metrics

---

## 🔧 Troubleshooting

### Ψ-Field Not Starting
```bash
# Check pod status
kubectl -n aurora-staging describe pod -l app=psi-field

# Check logs
kubectl -n aurora-staging logs -l app=psi-field --tail=100

# Common issues:
# - Missing ConfigMap: Check services/psi-field/k8s/configmap.yaml
# - Image pull error: Check image name in deployment.yaml
# - Port conflict: Ensure port 8001 is not used
```

### Harbinger Not Starting
```bash
# Check pod status
kubectl -n aurora-staging describe pod -l app=harbinger

# Check logs
kubectl -n aurora-staging logs -l app=harbinger --tail=100

# Common issues:
# - Missing dependencies: Run npm install locally first
# - TypeScript errors: Run npm test locally
# - Config missing: Check vmsh/config/harbinger.yaml
```

### Grafana Dashboards Not Showing Data
```bash
# Check Prometheus targets
kubectl -n aurora-staging port-forward svc/prometheus-server 9090:80 &
open http://localhost:9090/targets

# Verify metrics exist
curl http://localhost:9090/api/v1/query?query=psi_field_density

# Check dashboard queries
# - Open Grafana → Dashboard → Edit panel
# - Verify metric names match actual metrics
```

---

## 🎯 Next Steps After P0

### Week 2: Automation
- [ ] CI/CD pipeline for Ψ-Field
- [ ] CI/CD pipeline for Harbinger
- [ ] Auto-publish Merkle root on deploy
- [ ] Pre-commit hooks

### Week 3: Federation
- [ ] Deploy peer Remembrancer (Node B)
- [ ] Federation sync test
- [ ] Dual-signed receipt
- [ ] 27th smoke test

### Month 2: Intelligence
- [ ] Semantic search (embeddings)
- [ ] Coordinator TAM (Ψ-Field v1.1)
- [ ] Anchors service API
- [ ] IPFS integration

---

## 📞 Quick Reference

### Cluster Access
```bash
# Update kubeconfig
aws eks update-kubeconfig --name aurora-staging --region eu-west-1

# Verify access
kubectl cluster-info

# List all resources
kubectl -n aurora-staging get all
```

### Service URLs
```bash
# Grafana
kubectl -n aurora-staging get svc grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Prometheus
kubectl -n aurora-staging get svc prometheus-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Ollama
kubectl -n aurora-staging get ingress ollama-cpu-ing -o jsonpath='{.spec.rules[0].host}'
```

### Logs
```bash
# All pods in namespace
kubectl -n aurora-staging logs -l app=<app-name> --tail=100 -f

# Specific pod
kubectl -n aurora-staging logs <pod-name> --tail=100 -f

# Previous pod (if crashed)
kubectl -n aurora-staging logs <pod-name> --previous
```

---

## 🜂 The Covenant is Deployed

**Infrastructure:** ✅ EKS cluster operational (19+ hours)  
**Monitoring:** ✅ Prometheus + Grafana running  
**Metrics:** ✅ Aurora metrics exporter active  
**Next:** Deploy Ψ-Field + Harbinger (1 hour total)

**Execute P0 tasks now. Revenue enablement awaits. 🜂**

---

**Astra inclinant, sed non obligant.**
