import { z } from 'zod';

export const CONFIG = {
  PORT: parseInt(process.env.PORT || '8080', 10),
  LOG_LEVEL: process.env.LOG_LEVEL || 'info',
  NODE_ENV: process.env.NODE_ENV || 'development',
  ROUTER_MODE: process.env.ROUTER_MODE || 'rule-based',
  ROUTER_CONFIG_PATH: process.env.ROUTER_CONFIG_PATH || './config/router.yaml',
  PROVIDERS_CONFIG_PATH: process.env.PROVIDERS_CONFIG_PATH || './config/providers.yaml',
  METRICS_PREFIX: process.env.METRICS_PREFIX || 'aurora_',
  PSI_FIELD_URL: process.env.PSI_FIELD_URL || 'http://psi-field:8000',
  PSI_FIELD_ENABLED: process.env.PSI_FIELD_ENABLED === 'true',
  AI_ROUTER_ENABLED: process.env.AI_ROUTER_ENABLED === 'true',
  AI_ROLLOUT_PERCENTAGE: parseInt(process.env.AI_ROLLOUT_PERCENTAGE || '0', 10),
  AI_MODEL_PATH: process.env.AI_MODEL_PATH || './models/q-table.json',
};

// Routing request schema
export const RoutingRequestSchema = z.object({
  workload_type: z.enum(['llm_inference', 'llm_training', 'rendering', 'general']),
  gpu_type: z.enum(['a100', 'h100', 'a6000', '4090', 't4', 'l40']),
  region: z.string().default('global'),
  gpu_hours: z.number().positive(),
  max_price: z.number().positive().optional(),
  max_latency_ms: z.number().positive().optional(),
  min_reputation: z.number().min(0).max(100).optional(),
  weights: z.object({
    price: z.number().min(0).max(1).default(0.35),
    latency: z.number().min(0).max(1).default(0.30),
    reputation: z.number().min(0).max(1).default(0.20),
    availability: z.number().min(0).max(1).default(0.15),
  }).optional(),
});

export type RoutingRequest = z.infer<typeof RoutingRequestSchema>;

// Routing response schema
export const RoutingResponseSchema = z.object({
  provider: z.string(),
  price_usd_per_hour: z.number(),
  estimated_latency_ms: z.number(),
  deployment_id: z.string().optional(),
  status: z.enum(['provisioning', 'running', 'failed', 'no_capacity']),
  reason: z.string().optional(),
});

export type RoutingResponse = z.infer<typeof RoutingResponseSchema>;
