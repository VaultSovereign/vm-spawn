import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatNumber(value: number, decimals = 2): string {
  return value.toFixed(decimals);
}

export function formatPercentage(value: number, decimals = 1): string {
  return `${(value * 100).toFixed(decimals)}%`;
}

export function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

export function sigmoid(x: number): number {
  return 1 / (1 + Math.exp(-x));
}

// VaultMesh specific utilities
export function calculateRCS(
  frequency: number,
  witnesses: Array<{ alignment: number }>,
  entropy: number,
  mythConsistency: number
): number {
  const phi = 1.618;
  const tolerance = 0.1618;

  const phi_term = 1 - Math.abs(frequency - phi) / tolerance;
  const W = witnesses.reduce((sum, w) => sum + w.alignment, 0) / witnesses.length;
  const E = entropy;
  const M = mythConsistency;

  const rcs = 0.35 * phi_term + 0.35 * W + 0.15 * E + 0.15 * M;
  return clamp(rcs, 0, 1);
}

export function calculateShineIndex(rcs: number, alpha = 6, beta = 0.5): number {
  return sigmoid(alpha * (rcs - beta));
}

export function formatDuration(ms: number): string {
  if (ms < 1000) return `${ms.toFixed(0)}ms`;
  if (ms < 60000) return `${(ms / 1000).toFixed(1)}s`;
  if (ms < 3600000) return `${(ms / 60000).toFixed(1)}m`;
  return `${(ms / 3600000).toFixed(1)}h`;
}

export function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes}B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)}KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)}MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)}GB`;
}
