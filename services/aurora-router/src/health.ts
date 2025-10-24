let startTime = Date.now();
let lastRequestTime = 0;

export interface HealthStatus {
  status: 'healthy' | 'degraded' | 'unhealthy';
  uptime: number;
  lastRequest: number;
  mode: string;
  providers: {
    [key: string]: {
      healthy: boolean;
      latency_ms: number;
    };
  };
}

export function recordRequest() {
  lastRequestTime = Date.now();
}

export function getHealth(): HealthStatus {
  const uptime = (Date.now() - startTime) / 1000;
  const lastRequest = lastRequestTime ? (Date.now() - lastRequestTime) / 1000 : -1;

  return {
    status: 'healthy',
    uptime,
    lastRequest,
    mode: process.env.ROUTER_MODE || 'rule-based',
    providers: {},
  };
}

export function resetStartTime() {
  startTime = Date.now();
}
