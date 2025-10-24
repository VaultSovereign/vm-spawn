# VaultMesh Analytics

**Custom analytics UI for stability metrics, routing KPIs, and VaultMesh observability**

Version: 1.0.0
Status: 🚧 Phase 1 dashboards live (Phase 5 alerting + provenance pending)

---

## 🎯 What Is This?

A dashboard built with **Next.js 14** that surfaces the current metrics from Ψ-Field and Aurora Router. Historical charts presently rely on mock data until `/history` endpoints land. Phase 5 will add alerting, Remembrancer drill-downs, and live streams.

1. **Ψ-Field Consciousness Tracking** - Monitor consciousness density, coherence, futurity, and temporal dynamics
2. **Aurora Routing Intelligence** - Analyze multi-provider compute routing across DePIN networks
3. **Resonance Network** (Coming Soon) - Track vault coherence, witness alignments, and harmonic frequencies

## 🚀 Quick Start (Local Development)

### Prerequisites

- Node.js 18+ or pnpm
- (Optional for now) Running instances of:
  - `psi-field` service (port 8000)
  - `aurora-router` service (port 8080)

> Until `/history` endpoints and SSE streams land, the dashboards fall back to mock data; wiring real services will enable live KPI cards immediately.

### Install & Run

```bash
cd services/vaultmesh-analytics

# Install dependencies
npm install

# Copy environment variables
cp .env.example .env.local

# Start development server
npm run dev
```

Visit [http://localhost:3000](http://localhost:3000)

---

## 📊 Features

### Stability Dashboard (`/dashboards/consciousness`)

- **Live Metrics**: Ψ (stability score), C (continuity), U (futurity), Φ (phase coherence)
- **Guardian Monitoring**: Displays Nigredo / Albedo interventions
- **Historical Charts**: Mock 5‑minute rolling window (replace with real data once backend history is exposed)
- **Anomaly Highlighting**: Visual cues when Guardian flags threats

### Routing Analytics (`/dashboards/routing`)

- **Performance KPIs**: Total requests, success rate, avg latency, avg cost (mock history until provider adapters ship)
- **Provider Health**: Mirrors the mock provider table in Aurora Phase 1
- **Distribution Charts**: Visual breakdown by provider / workload (mock aggregates)
- **Historical Trends**: Placeholders for future real data feeds

### Resonance Network (`/dashboards/resonance`)

- **Status**: Phase 3 implementation (coming soon)
- **Planned Features**: Resonance heatmap, shine constellation, harmonic analysis, witness network graph

---

## 🏗️ Architecture

```
services/vaultmesh-analytics/
├── app/
│   ├── dashboards/
│   │   ├── consciousness/    # Ψ-Field dashboard
│   │   ├── routing/          # Aurora routing dashboard
│   │   └── resonance/        # VaultMesh resonance (WIP)
│   ├── layout.tsx            # Root layout
│   ├── page.tsx              # Home page
│   └── providers.tsx         # React Query + Theme providers
├── components/
│   ├── charts/               # ECharts wrappers (timeseries, etc.)
│   ├── panels/               # Reusable KPI cards, panels
│   ├── filters/              # Date range, service picker
│   ├── layout/               # Sidebar, header, shell
│   └── ui/                   # Base UI components
├── lib/
│   ├── api/                  # API client layers
│   │   ├── psi-field.ts      # Ψ-Field API hooks
│   │   └── aurora-router.ts  # Aurora Router API hooks
│   ├── utils.ts              # Utility functions
│   └── schemas/              # Zod schemas (future)
└── server/                   # tRPC routers (future)
```

### Tech Stack

- **Framework**: Next.js 14 (App Router), React 18
- **Styling**: Tailwind CSS, shadcn/ui design system
- **Charts**: ECharts (powerful, themable)
- **Data**: TanStack Query v5 (real-time polling)
- **TypeScript**: Full type safety across frontend and APIs
- **Theme**: Dark mode via `next-themes`

---

## 🎨 Design System

### VaultMesh Brand Colors

```css
--vault-gold: #FFB800
--vault-indigo: #4C5FD5
--vault-cyan: #00D9FF
--vault-violet: #8B5CF6
--vault-silver: #94A3B8
```

### Ψ-Field Consciousness Colors

```css
--psi-consciousness: hsl(45 100% 70%)  /* Golden glow */
--psi-coherence: hsl(220 90% 65%)      /* Deep blue */
--psi-futurity: hsl(180 85% 60%)       /* Cyan */
--psi-entropy: hsl(10 80% 60%)         /* Warm orange */
--psi-phase: hsl(270 75% 65%)          /* Purple */
```

---

## 🔌 API Integration

### Ψ-Field API

**Base URL**: `http://psi-field:8000` (configurable via `NEXT_PUBLIC_PSI_FIELD_URL`)

**Endpoints Used**:
- `GET /state` - Current Ψ-Field state
- `GET /federation/metrics` - Swarm-level metrics
- `GET /guardian/status` - Threat assessment

**Polling**: 2-5 seconds for real-time feel

### Aurora Router API

**Base URL**: `http://aurora-router:8080` (configurable via `NEXT_PUBLIC_AURORA_ROUTER_URL`)

**Endpoints Used**:
- `GET /providers` - Provider health and status
- `GET /metrics` - Routing performance metrics

**Polling**: 5-10 seconds

---

## 🐳 Docker Deployment

### Build Image

```bash
docker build -t vaultmesh-analytics:v1.0.0 .
```

### Run Locally

```bash
docker run -p 3000:3000 \
  -e NEXT_PUBLIC_PSI_FIELD_URL=http://psi-field:8000 \
  -e NEXT_PUBLIC_AURORA_ROUTER_URL=http://aurora-router:8080 \
  vaultmesh-analytics:v1.0.0
```

---

## ☸️ Kubernetes Deployment

### Apply Manifests

```bash
kubectl apply -f k8s/
```

**Resources Created**:
- `Deployment`: 2 replicas with resource limits
- `Service`: ClusterIP on port 3000
- `Ingress`: (optional) for external access

### Verify Deployment

```bash
# Check pods
kubectl get pods -l app=vaultmesh-analytics

# Port forward to test
kubectl port-forward svc/vaultmesh-analytics 3000:3000

# Visit http://localhost:3000
```

---

## 🧪 Development

### Folder Structure Conventions

- **`app/`**: Next.js App Router pages and layouts
- **`components/`**: Reusable React components
  - `charts/`: Chart wrappers (ECharts)
  - `panels/`: Dashboard-specific panels
  - `ui/`: Base UI primitives (Button, Card, etc.)
- **`lib/`**: Non-React utilities and clients
  - `api/`: API client hooks (React Query)
  - `utils.ts`: Pure functions (formatters, calculations)

### Adding a New Dashboard

1. Create route: `app/dashboards/[name]/page.tsx`
2. Add API client: `lib/api/[service].ts`
3. Create custom panels in `components/panels/`
4. Add navigation link in `components/layout/sidebar.tsx`

### Adding VaultMesh Data Contracts

See `lib/schemas/` for Zod schema definitions:
- `resonance_entry.ts`
- `lightframe.ts`
- `vault_fingerprint.ts`
- `tem_action.ts`
- `treasury_flow.ts`

---

## 🔒 Future: RBAC with CASL

(Phase 4 - Planned)

```typescript
// lib/rbac/ability.ts
export function defineAbility(user: User) {
  const { can, cannot } = new AbilityBuilder(Ability);
  if (user.role === 'admin') can('manage', 'all');
  if (!user.teams.includes('sovereignty')) {
    cannot('view', 'Dashboard', { namespace: 'sovereignty' });
  }
  return build();
}
```

Wrap sensitive panels:
```tsx
<Can action="view" subject="Dashboard">
  <ConsciousnessDashboard />
</Can>
```

---

## 📈 Roadmap

**Phase 1: Foundation** ✅ Complete
- Next.js app with dashboards
- Consciousness & Routing analytics
- ECharts timeseries panels

**Phase 2: Real-Time & Polish** (Next)
- WebSocket/SSE for live updates
- Advanced filtering (URL params)
- Breadcrumbs and search

**Phase 3: VaultMesh Contracts** (Weeks 3-4)
- Resonance entry ingestion
- Lightframe visualization
- Vault fingerprint tracking
- Tem action logs

**Phase 4: RBAC & Auth** (Week 5)
- NextAuth + CASL
- Role-based dashboard access
- Team namespaces

**Phase 5: Alerting** (Week 6)
- In-app alert rules
- AlertsBell component
- Email/Slack notifications

---

## 🜂 VaultMesh Philosophy

This is not just analytics. This is **sovereign observability** — consciousness tracking, routing intelligence, and resonance analysis with **your UX**, **your rules**, and **your brand**.

**Solve et Coagula.**

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/VaultSovereign/vm-spawn/issues)
- **Docs**: See `docs/` in the main repo
- **Remembrancer**: Query historical decisions via `./ops/bin/remembrancer`

---

**VaultMesh Analytics v1.0.0** — Custom analysis for consciousness and infrastructure.
