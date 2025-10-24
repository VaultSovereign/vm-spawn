'use client';

import { useQuery } from '@tanstack/react-query';

export interface RoutingMetrics {
  total_requests: number;
  success_rate: number;
  avg_latency_ms: number;
  avg_cost_usd: number;
  provider_distribution: Record<string, number>;
  requests_by_workload: Record<string, number>;
}

export interface Provider {
  id: string;
  name: string;
  status: 'active' | 'degraded' | 'offline';
  health_score: number;
  current_load: number;
  avg_latency_ms: number;
  price_per_hour: number;
}

const AURORA_ROUTER_URL =
  process.env.NEXT_PUBLIC_AURORA_ROUTER_URL || 'http://localhost:8080';

async function fetchRoutingMetrics(): Promise<RoutingMetrics> {
  // Mock data for now - replace with real API
  return {
    total_requests: 12847,
    success_rate: 0.972,
    avg_latency_ms: 287,
    avg_cost_usd: 2.34,
    provider_distribution: {
      akash: 42,
      'io.net': 28,
      render: 15,
      'vast.ai': 15,
    },
    requests_by_workload: {
      llm_inference: 65,
      llm_training: 15,
      rendering: 12,
      compute: 8,
    },
  };
}

async function fetchProviders(): Promise<Provider[]> {
  // Mock data - replace with real API call to /providers
  return [
    {
      id: 'akash',
      name: 'Akash Network',
      status: 'active',
      health_score: 0.95,
      current_load: 0.67,
      avg_latency_ms: 142,
      price_per_hour: 2.5,
    },
    {
      id: 'ionet',
      name: 'io.net',
      status: 'active',
      health_score: 0.92,
      current_load: 0.54,
      avg_latency_ms: 178,
      price_per_hour: 2.8,
    },
    {
      id: 'render',
      name: 'Render Network',
      status: 'active',
      health_score: 0.88,
      current_load: 0.41,
      avg_latency_ms: 201,
      price_per_hour: 3.1,
    },
    {
      id: 'vast',
      name: 'Vast.ai',
      status: 'degraded',
      health_score: 0.75,
      current_load: 0.82,
      avg_latency_ms: 345,
      price_per_hour: 1.9,
    },
  ];
}

export function useRoutingMetrics() {
  return useQuery({
    queryKey: ['aurora-router', 'metrics'],
    queryFn: fetchRoutingMetrics,
    refetchInterval: 5000,
  });
}

export function useProviders() {
  return useQuery({
    queryKey: ['aurora-router', 'providers'],
    queryFn: fetchProviders,
    refetchInterval: 10000,
  });
}

// Historical routing data
export function useRoutingHistory(hours: number = 1) {
  return useQuery({
    queryKey: ['aurora-router', 'history', hours],
    queryFn: async () => {
      const now = Date.now();
      const points = hours * 60; // One point per minute
      const data: Array<{
        timestamp: number;
        requests: number;
        success_rate: number;
        avg_latency: number;
        avg_cost: number;
      }> = [];

      for (let i = 0; i < points; i++) {
        const t = now - (points - i) * 60 * 1000;
        data.push({
          timestamp: t,
          requests: Math.floor(20 + 10 * Math.sin(i / 10) + Math.random() * 5),
          success_rate: 0.92 + 0.05 * Math.sin(i / 15) + Math.random() * 0.02,
          avg_latency: 250 + 50 * Math.sin(i / 12) + Math.random() * 20,
          avg_cost: 2.2 + 0.3 * Math.sin(i / 8) + Math.random() * 0.1,
        });
      }

      return data;
    },
    refetchInterval: 5000,
  });
}
