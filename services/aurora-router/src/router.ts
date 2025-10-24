/**
 * Multi-Provider Routing Engine
 * Ported from sim/multi-provider-routing-simulator
 */

import { RoutingRequest, RoutingResponse } from './config.js';
import { logger } from './logger.js';

export interface ProviderState {
  id: string;
  name: string;
  regions: string[];
  gpu_types: string[];
  price_usd_per_hour: { [gpu_type: string]: number };
  base_latency_ms: number;
  capacity_gpu_hours_per_step: number;
  reputation: number;
  active: boolean;
}

export interface ProviderScore {
  provider_id: string;
  score: number;
  price: number;
  latency: number;
  reputation: number;
  capacity: number;
}

export class Router {
  private providers: Map<string, ProviderState>;
  private capacityRemaining: Map<string, number>;

  constructor(providers: ProviderState[]) {
    this.providers = new Map(providers.map(p => [p.id, p]));
    this.capacityRemaining = new Map();
    this.resetCapacity();
  }

  resetCapacity() {
    this.providers.forEach((p, id) => {
      this.capacityRemaining.set(id, p.capacity_gpu_hours_per_step);
    });
  }

  route(req: RoutingRequest): RoutingResponse {
    const startTime = Date.now();

    // Phase 1: Filter incompatible providers
    const candidates = this.filterProviders(req);

    if (candidates.length === 0) {
      logger.warn({ req }, 'No viable providers found');
      return {
        provider: 'none',
        price_usd_per_hour: 0,
        estimated_latency_ms: 0,
        status: 'no_capacity',
        reason: 'no_viable_provider',
      };
    }

    // Phase 2: Score providers
    const scored = this.scoreProviders(req, candidates);

    // Phase 3: Select best provider
    const best = scored[0];
    const provider = this.providers.get(best.provider_id)!;

    // Deduct capacity
    const remaining = this.capacityRemaining.get(best.provider_id)! - req.gpu_hours;
    this.capacityRemaining.set(best.provider_id, remaining);

    const duration = Date.now() - startTime;
    logger.info({
      provider: best.provider_id,
      score: best.score,
      price: best.price,
      latency: best.latency,
      duration_ms: duration,
    }, 'Routed request');

    return {
      provider: best.provider_id,
      price_usd_per_hour: best.price,
      estimated_latency_ms: best.latency,
      status: 'provisioning',
    };
  }

  private filterProviders(req: RoutingRequest): string[] {
    const candidates: string[] = [];

    this.providers.forEach((p, id) => {
      if (!p.active) return;

      // Region check
      if (req.region !== 'global' &&
          !p.regions.includes(req.region) &&
          !p.regions.includes('global')) {
        return;
      }

      // GPU type check
      if (!p.gpu_types.includes(req.gpu_type)) {
        return;
      }

      // Price check
      const price = p.price_usd_per_hour[req.gpu_type] || 999;
      if (req.max_price && price > req.max_price) {
        return;
      }

      // Latency check
      if (req.max_latency_ms && p.base_latency_ms > req.max_latency_ms) {
        return;
      }

      // Reputation check
      if (req.min_reputation && p.reputation < req.min_reputation) {
        return;
      }

      // Capacity check
      const remaining = this.capacityRemaining.get(id) || 0;
      if (remaining < req.gpu_hours) {
        return;
      }

      candidates.push(id);
    });

    return candidates;
  }

  private scoreProviders(req: RoutingRequest, candidates: string[]): ProviderScore[] {
    const weights = req.weights || {
      price: 0.35,
      latency: 0.30,
      reputation: 0.20,
      availability: 0.15,
    };

    const scores: ProviderScore[] = candidates.map(id => {
      const p = this.providers.get(id)!;
      const price = p.price_usd_per_hour[req.gpu_type] || 999;
      const latency = p.base_latency_ms;
      const reputation = p.reputation;
      const capacity = this.capacityRemaining.get(id) || 0;
      const totalCapacity = p.capacity_gpu_hours_per_step;

      // Normalize and compute weighted score
      const priceScore = weights.price * (1 / Math.max(0.1, price));
      const latencyScore = weights.latency * (1 / Math.max(1, latency));
      const reputationScore = weights.reputation * (reputation / 100);
      const availabilityScore = weights.availability * (capacity / totalCapacity);

      const totalScore = priceScore + latencyScore + reputationScore + availabilityScore;

      return {
        provider_id: id,
        score: totalScore,
        price,
        latency,
        reputation,
        capacity,
      };
    });

    // Sort by score descending
    scores.sort((a, b) => b.score - a.score);

    return scores;
  }

  getProviderState(id: string): ProviderState | undefined {
    return this.providers.get(id);
  }

  getAllProviders(): ProviderState[] {
    return Array.from(this.providers.values());
  }
}
