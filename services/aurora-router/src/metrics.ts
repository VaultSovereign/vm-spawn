import { Registry, Counter, Histogram, Gauge } from 'prom-client';
import { CONFIG } from './config.js';

export const register = new Registry();

// Routing metrics
export const routeRequests = new Counter({
  name: `${CONFIG.METRICS_PREFIX}route_requests_total`,
  help: 'Total number of routing requests',
  labelNames: ['provider', 'status'],
  registers: [register],
});

export const routeDuration = new Histogram({
  name: `${CONFIG.METRICS_PREFIX}route_duration_seconds`,
  help: 'Duration of routing decisions',
  labelNames: ['provider', 'mode'],
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1],
  registers: [register],
});

export const routeFailures = new Counter({
  name: `${CONFIG.METRICS_PREFIX}route_failures_total`,
  help: 'Total routing failures',
  labelNames: ['provider', 'reason'],
  registers: [register],
});

export const activeDeployments = new Gauge({
  name: `${CONFIG.METRICS_PREFIX}active_deployments`,
  help: 'Number of active deployments',
  labelNames: ['provider'],
  registers: [register],
});

// Provider health metrics
export const providerHealth = new Gauge({
  name: `${CONFIG.METRICS_PREFIX}provider_health`,
  help: 'Provider health status (1=healthy, 0=unhealthy)',
  labelNames: ['provider'],
  registers: [register],
});

export const providerLatency = new Gauge({
  name: `${CONFIG.METRICS_PREFIX}provider_latency_ms`,
  help: 'Provider latency in milliseconds',
  labelNames: ['provider'],
  registers: [register],
});

export const providerCost = new Gauge({
  name: `${CONFIG.METRICS_PREFIX}provider_cost_usd`,
  help: 'Provider cost per hour in USD',
  labelNames: ['provider', 'gpu_type'],
  registers: [register],
});

export const providerCapacity = new Gauge({
  name: `${CONFIG.METRICS_PREFIX}provider_capacity`,
  help: 'Provider remaining capacity',
  labelNames: ['provider'],
  registers: [register],
});

// AI metrics (Phase 3)
export const aiDecisions = new Counter({
  name: `${CONFIG.METRICS_PREFIX}ai_decisions_total`,
  help: 'Total AI routing decisions',
  labelNames: ['mode'],
  registers: [register],
});

export const aiReward = new Gauge({
  name: `${CONFIG.METRICS_PREFIX}ai_reward`,
  help: 'Current AI agent reward',
  labelNames: ['episode'],
  registers: [register],
});
