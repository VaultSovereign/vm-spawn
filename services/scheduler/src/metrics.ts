import { Counter, Gauge, Histogram, Registry } from 'prom-client';

export const register = new Registry();

export const anchorsAttempted = new Counter({
  name: 'vmsh_anchors_attempted_total',
  help: 'Total anchor attempts',
  labelNames: ['namespace','cadence','target'],
  registers: [register],
});

export const anchorsSucceeded = new Counter({
  name: 'vmsh_anchors_succeeded_total',
  help: 'Successful anchors',
  labelNames: ['namespace','cadence','target'],
  registers: [register],
});

export const anchorsFailed = new Counter({
  name: 'vmsh_anchors_failed_total',
  help: 'Failed anchors',
  labelNames: ['namespace','cadence','target'],
  registers: [register],
});

export const backoffState = new Gauge({
  name: 'vmsh_backoff_state',
  help: 'Current backoff level per namespace',
  labelNames: ['namespace'],
  registers: [register],
});

export const anchorDuration = new Histogram({
  name: 'vmsh_anchor_duration_seconds',
  help: 'Duration of anchor operations',
  labelNames: ['namespace','cadence','target','status'],
  registers: [register],
});

