import path from 'path';
import { config as loadDotenv } from 'dotenv';

loadDotenv();

export const CONFIG = {
  ROOT: process.env.VMSH_ROOT ? path.resolve(process.env.VMSH_ROOT) : path.resolve(path.join(__dirname, '../../..')),
  NS_PATH: process.env.VMSH_NAMESPACES || path.resolve(path.join(__dirname, '../../..', 'vmsh/config/namespaces.yaml')),
  STATE_PATH: process.env.VMSH_STATE || path.resolve(path.join(__dirname, '../../..', 'out/state/scheduler.json')),
  TICK_INTERVAL: parseInt(process.env.VMSH_TICK_MS || '10000', 10),
  BASE_BACKOFF: parseInt(process.env.VMSH_BASE_BACKOFF || '5', 10),
  MAX_BACKOFF: parseInt(process.env.VMSH_MAX_BACKOFF || '7', 10),
  METRICS_PORT: parseInt(process.env.METRICS_PORT || '9090', 10),
} as const;

export const PHI = 1.618033988749895; // sacred ratio

