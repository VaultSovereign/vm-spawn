import fs from 'fs';
import { CONFIG } from './config.js';

type NamespaceHealth = {
  lastAnchor: Record<string, number>;
  backoff: number;
  status: 'ok' | 'backing_off' | 'stale';
};

export interface HealthStatus {
  status: 'healthy' | 'degraded' | 'unhealthy';
  uptime: number;
  lastTick: number;
  namespaces: Record<string, NamespaceHealth>;
}

let lastTickTime = 0;
export function recordTick() { lastTickTime = Date.now(); }

function safeReadState(): any {
  try {
    const raw = fs.readFileSync(CONFIG.STATE_PATH, 'utf8');
    return JSON.parse(raw);
  } catch { return {}; }
}

export function getHealth(): HealthStatus {
  const uptime = process.uptime();
  const state = safeReadState();
  const now = Math.floor(Date.now()/1000);
  const namespaces: Record<string, NamespaceHealth> = {};
  let degraded = 0;

  for (const [ns, nsState] of Object.entries<any>(state)) {
    const last = nsState.last || {};
    const lastValues = Object.values(last).filter((v): v is number => typeof v === 'number');
    const mostRecent = lastValues.length > 0 ? Math.max(0, ...lastValues) : 0;
    const staleCutoff = now - 3600;
    const status: NamespaceHealth['status'] = nsState.backoff > 3 ? 'backing_off' : (mostRecent < staleCutoff ? 'stale' : 'ok');
    namespaces[ns] = { lastAnchor: last, backoff: nsState.backoff || 0, status };
    if (status !== 'ok') degraded++;
  }

  const tickAge = (Date.now() - lastTickTime) / 1000;
  const status = tickAge > 60 ? 'unhealthy' : (degraded > 0 ? 'degraded' : 'healthy');
  return { status, uptime, lastTick: lastTickTime, namespaces };
}

