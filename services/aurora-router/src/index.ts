import express from 'express';
import { CONFIG, RoutingRequestSchema } from './config.js';
import { logger } from './logger.js';
import { register, routeRequests, routeDuration, routeFailures } from './metrics.js';
import { getHealth, recordRequest } from './health.js';
import { Router, ProviderState } from './router.js';

const app = express();
app.use(express.json());

// Mock provider data for Phase 1
// In Phase 2, this will be loaded from config and updated from provider APIs
const MOCK_PROVIDERS: ProviderState[] = [
  {
    id: 'akash',
    name: 'Akash Network',
    regions: ['us-west', 'us-east', 'eu-central'],
    gpu_types: ['a100', 't4', 'a6000'],
    price_usd_per_hour: { a100: 2.50, t4: 0.40, a6000: 1.20 },
    base_latency_ms: 120,
    capacity_gpu_hours_per_step: 1000,
    reputation: 95,
    active: true,
  },
  {
    id: 'ionet',
    name: 'io.net',
    regions: ['global'],
    gpu_types: ['h100', 'a100', '4090'],
    price_usd_per_hour: { h100: 4.00, a100: 2.80, '4090': 1.50 },
    base_latency_ms: 150,
    capacity_gpu_hours_per_step: 800,
    reputation: 90,
    active: true,
  },
  {
    id: 'render',
    name: 'Render Network',
    regions: ['us-west', 'eu-west'],
    gpu_types: ['4090', 't4'],
    price_usd_per_hour: { '4090': 1.80, t4: 0.50 },
    base_latency_ms: 100,
    capacity_gpu_hours_per_step: 500,
    reputation: 85,
    active: true,
  },
  {
    id: 'vastai',
    name: 'Vast.ai',
    regions: ['global'],
    gpu_types: ['a100', 'a6000', '4090', 't4'],
    price_usd_per_hour: { a100: 2.20, a6000: 1.00, '4090': 1.40, t4: 0.35 },
    base_latency_ms: 180,
    capacity_gpu_hours_per_step: 1200,
    reputation: 80,
    active: true,
  },
];

// Initialize router
const router = new Router(MOCK_PROVIDERS);

// Routes
app.post('/route', (req, res) => {
  recordRequest();
  const startTime = Date.now();

  try {
    const validated = RoutingRequestSchema.parse(req.body);
    logger.info({ request: validated }, 'Routing request received');

    const response = router.route(validated);

    const duration = (Date.now() - startTime) / 1000;
    routeRequests.inc({ provider: response.provider, status: response.status });
    routeDuration.observe({ provider: response.provider, mode: 'rule-based' }, duration);

    if (response.status === 'no_capacity') {
      routeFailures.inc({ provider: response.provider, reason: response.reason || 'unknown' });
      return res.status(503).json(response);
    }

    res.json(response);
  } catch (error: any) {
    logger.error({ error: error.message }, 'Routing request failed');
    routeFailures.inc({ provider: 'none', reason: 'validation_error' });
    res.status(400).json({ error: error.message });
  }
});

app.get('/providers', (_req, res) => {
  const providers = router.getAllProviders().map(p => ({
    id: p.id,
    name: p.name,
    active: p.active,
    regions: p.regions,
    gpu_types: p.gpu_types,
    reputation: p.reputation,
    base_latency_ms: p.base_latency_ms,
  }));

  res.json({ providers });
});

app.get('/providers/:id', (req, res) => {
  const provider = router.getProviderState(req.params.id);

  if (!provider) {
    return res.status(404).json({ error: 'Provider not found' });
  }

  res.json(provider);
});

app.get('/health', (_req, res) => {
  const health = getHealth();
  const statusCode = health.status === 'healthy' ? 200 : 503;
  res.status(statusCode).json(health);
});

app.get('/metrics', async (_req, res) => {
  res.set('Content-Type', register.contentType);
  res.send(await register.metrics());
});

// Start server
app.listen(CONFIG.PORT, () => {
  logger.info({
    port: CONFIG.PORT,
    mode: CONFIG.ROUTER_MODE,
    providers: MOCK_PROVIDERS.length,
  }, 'Aurora Router started');
});

// Reset capacity every 60 seconds (simulating step intervals)
setInterval(() => {
  router.resetCapacity();
  logger.debug('Capacity reset');
}, 60000);
