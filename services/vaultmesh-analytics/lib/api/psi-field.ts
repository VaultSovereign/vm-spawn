'use client';

import { useQuery } from '@tanstack/react-query';

// Types matching the psi-field API
export interface PsiState {
  Psi: number;
  C: number;
  U: number;
  Phi: number;
  H: number;
  PE: number;
  M: number;
  dt_eff: number;
  k: number;
  timestamp: string;
  _guardian?: {
    intervention?: string;
    reason?: string;
  };
}

export interface FederationMetrics {
  agent_id: string;
  psi: number;
  metrics: {
    C: number;
    U: number;
    Phi: number;
    H: number;
    PE: number;
    M: number;
  };
  timestamp: number;
}

// API base URL from env or default
const PSI_FIELD_URL = process.env.NEXT_PUBLIC_PSI_FIELD_URL || 'http://localhost:8000';

// Fetch functions
async function fetchPsiState(): Promise<PsiState> {
  const response = await fetch(`${PSI_FIELD_URL}/state`);
  if (!response.ok) {
    throw new Error('Failed to fetch Ψ-Field state');
  }
  return response.json();
}

async function fetchFederationMetrics(): Promise<FederationMetrics> {
  const response = await fetch(`${PSI_FIELD_URL}/federation/metrics`);
  if (!response.ok) {
    throw new Error('Failed to fetch federation metrics');
  }
  return response.json();
}

async function fetchGuardianStatus(): Promise<any> {
  const response = await fetch(`${PSI_FIELD_URL}/guardian/status`);
  if (!response.ok) {
    throw new Error('Failed to fetch guardian status');
  }
  return response.json();
}

// React Query hooks
export function usePsiState() {
  return useQuery({
    queryKey: ['psi-field', 'state'],
    queryFn: fetchPsiState,
    refetchInterval: 2000, // Real-time: refetch every 2 seconds
  });
}

export function useFederationMetrics() {
  return useQuery({
    queryKey: ['psi-field', 'federation'],
    queryFn: fetchFederationMetrics,
    refetchInterval: 5000,
  });
}

export function useGuardianStatus() {
  return useQuery({
    queryKey: ['psi-field', 'guardian'],
    queryFn: fetchGuardianStatus,
    refetchInterval: 5000,
  });
}

// Mock historical data generator (replace with real API later)
export function usePsiHistory(minutes: number = 5) {
  return useQuery({
    queryKey: ['psi-field', 'history', minutes],
    queryFn: async () => {
      // Generate mock historical data
      // In production, this would call a real endpoint like:
      // GET /psi-field/history?from=${from}&to=${to}

      const now = Date.now();
      const points = 60 * minutes; // One point per second
      const data: Array<{
        timestamp: number;
        Psi: number;
        C: number;
        U: number;
        Phi: number;
        H: number;
        PE: number;
      }> = [];

      for (let i = 0; i < points; i++) {
        const t = now - (points - i) * 1000;
        data.push({
          timestamp: t,
          Psi: 0.5 + 0.3 * Math.sin(i / 10) + Math.random() * 0.1,
          C: 0.7 + 0.2 * Math.sin(i / 15) + Math.random() * 0.05,
          U: 0.6 + 0.25 * Math.sin(i / 12) + Math.random() * 0.05,
          Phi: 0.4 + 0.3 * Math.sin(i / 8) + Math.random() * 0.1,
          H: 0.3 + 0.2 * Math.sin(i / 20) + Math.random() * 0.05,
          PE: 0.4 + 0.3 * Math.sin(i / 7) + Math.random() * 0.1,
        });
      }

      return data;
    },
    refetchInterval: 2000,
  });
}
