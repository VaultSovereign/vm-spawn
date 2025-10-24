# VaultMesh Analytics — Quick Start Guide

**Get your custom analytics UI running in 5 minutes**

---

## Prerequisites

- Node.js 18+ or pnpm
- Running services (optional for development with mock data):
  - psi-field on port 8000
  - aurora-router on port 8080

---

## Local Development

### 1. Install Dependencies

```bash
cd services/vaultmesh-analytics
npm install
```

### 2. Configure Environment

```bash
cp .env.example .env.local
```

Edit `.env.local`:
```env
NEXT_PUBLIC_PSI_FIELD_URL=http://localhost:8000
NEXT_PUBLIC_AURORA_ROUTER_URL=http://localhost:8080
```

### 3. Start Development Server

```bash
npm run dev
```

Visit [http://localhost:3000](http://localhost:3000)

### 4. Explore Dashboards

- **Home**: `/` - Landing page with overview
- **Consciousness**: `/dashboards/consciousness` - Ψ-Field metrics
- **Routing**: `/dashboards/routing` - Aurora routing analytics
- **Resonance**: `/dashboards/resonance` - (Coming soon)

---

## Docker Deployment

### Build Image

```bash
docker build -t vaultmesh/analytics:v1.0.0 .
```

### Run Container

```bash
docker run -d \
  --name vaultmesh-analytics \
  -p 3000:3000 \
  -e NEXT_PUBLIC_PSI_FIELD_URL=http://psi-field:8000 \
  -e NEXT_PUBLIC_AURORA_ROUTER_URL=http://aurora-router:8080 \
  vaultmesh/analytics:v1.0.0
```

---

## Kubernetes Deployment

### Prerequisites

- Kubernetes cluster (GKE, EKS, or local)
- kubectl configured
- psi-field and aurora-router services deployed

### Deploy

```bash
# Apply manifests
kubectl apply -f k8s/deployment.yaml

# Check status
kubectl get pods -l app=vaultmesh-analytics
kubectl get svc vaultmesh-analytics

# Port forward to test
kubectl port-forward svc/vaultmesh-analytics 3000:3000
```

### Access via Ingress

If you have nginx-ingress installed:

```bash
# Add to /etc/hosts
echo "127.0.0.1 analytics.vaultmesh.local" | sudo tee -a /etc/hosts

# Visit http://analytics.vaultmesh.local
```

---

## Features Overview

### Consciousness Dashboard
- **Real-time metrics**: Ψ, C, U, Φ, H, PE, M
- **Guardian status**: Active interventions and threat assessments
- **Historical charts**: 5-minute rolling window with 6 timeseries panels
- **Auto-refresh**: Every 2 seconds

### Routing Dashboard
- **KPIs**: Total requests, success rate, latency, cost
- **Provider health**: Status of Akash, io.net, Render, Vast.ai
- **Distribution charts**: Provider selection and workload types
- **Historical trends**: 1-hour rolling window

### Design System
- **Dark mode**: Automatic via next-themes
- **VaultMesh colors**: Gold, indigo, cyan, violet, silver
- **Ψ-Field colors**: Consciousness, coherence, futurity, entropy, phase
- **Responsive**: Mobile, tablet, desktop

---

## Development Tips

### Adding a New Dashboard

1. Create route: `app/dashboards/[name]/page.tsx`
2. Add API client: `lib/api/[service].ts`
3. Update sidebar: `components/layout/sidebar.tsx`

### Using VaultMesh Data Contracts

```typescript
import { ResonanceEntrySchema, calculateRCS } from '@/lib/schemas';
import { calculateShineIndex } from '@/lib/vaultmesh/coherence';

const entry = ResonanceEntrySchema.parse(data);
const { rcs, shine_index } = calculateRCSFromEntry(entry, spectrum);
```

### Custom Panels

See `components/panels/kpi-card.tsx` and `components/charts/timeseries-panel.tsx` for examples.

---

## Troubleshooting

### Port 3000 already in use

```bash
PORT=3001 npm run dev
```

### API connection errors

1. Check services are running:
   ```bash
   curl http://localhost:8000/health  # psi-field
   curl http://localhost:8080/health  # aurora-router
   ```

2. Update `.env.local` with correct URLs

### Build errors

```bash
# Clear Next.js cache
rm -rf .next

# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install

# Rebuild
npm run build
```

---

## Next Steps

1. **Connect real APIs**: Replace mock data with actual psi-field and aurora-router endpoints
2. **Add authentication**: Implement NextAuth for user management
3. **RBAC**: Use CASL to restrict dashboard access by role
4. **Alerting**: Build alert rules and notifications
5. **Resonance Dashboard**: Implement Phase 3 features

---

## Resources

- **Full README**: [README.md](./README.md)
- **Architecture Docs**: `docs/` in main repo
- **VaultMesh Codex**: `SOVEREIGN_LORE_CODEX_V1.md`
- **GitHub Issues**: [vm-spawn/issues](https://github.com/VaultSovereign/vm-spawn/issues)

---

**VaultMesh Analytics v1.0.0** 🜂 **Solve et Coagula**
