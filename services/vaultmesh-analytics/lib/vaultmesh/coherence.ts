/**
 * VaultMesh Coherence Calculations
 *
 * Implements the Resonance Coherence Score (RCS) and Shine Index calculations
 * as specified in the VaultMesh Analysis Architecture.
 */

import type { ResonanceEntry, Witness } from '../schemas';

/**
 * Calculate Resonance Coherence Score (RCS)
 *
 * RCS = clamp(0,1)[ w1*φ_term + w2*W + w3*E + w4*M ]
 *
 * Where:
 * - φ_term: Golden ratio alignment (1.618 ± tolerance)
 * - W: Mean witness alignment
 * - E: Entropy balance (spectral diversity)
 * - M: Mythographic consistency (embedding similarity)
 *
 * Default weights: w1=0.35, w2=0.35, w3=0.15, w4=0.15
 */
export function calculateRCS(
  frequency: number,
  witnesses: Witness[],
  entropy: number,
  mythConsistency: number,
  weights: { w1?: number; w2?: number; w3?: number; w4?: number } = {}
): number {
  const phi = 1.618; // Golden ratio
  const tolerance = 0.1618; // φ tolerance

  // Default weights
  const w1 = weights.w1 ?? 0.35;
  const w2 = weights.w2 ?? 0.35;
  const w3 = weights.w3 ?? 0.15;
  const w4 = weights.w4 ?? 0.15;

  // φ_term: Golden ratio alignment
  const delta_phi = Math.abs(frequency - phi) / tolerance;
  const phi_term = Math.max(0, 1 - delta_phi);

  // W: Mean witness alignment
  const W =
    witnesses.length > 0
      ? witnesses.reduce((sum, w) => sum + w.alignment, 0) / witnesses.length
      : 0;

  // E: Entropy balance (0..1, 1=healthy diversity)
  const E = Math.min(1, Math.max(0, entropy));

  // M: Mythographic consistency (0..1)
  const M = Math.min(1, Math.max(0, mythConsistency));

  // Calculate RCS
  const rcs = w1 * phi_term + w2 * W + w3 * E + w4 * M;

  // Clamp to [0, 1]
  return Math.min(1, Math.max(0, rcs));
}

/**
 * Calculate Shine Index (SI)
 *
 * SI = sigmoid( α * (RCS - β) )
 *
 * Where:
 * - α: Sensitivity parameter (default: 6)
 * - β: Midpoint threshold (default: 0.5)
 */
export function calculateShineIndex(rcs: number, alpha = 6, beta = 0.5): number {
  return sigmoid(alpha * (rcs - beta));
}

/**
 * Sigmoid function
 */
function sigmoid(x: number): number {
  return 1 / (1 + Math.exp(-x));
}

/**
 * Calculate spectral entropy
 *
 * Measures diversity in spectral bins.
 * Returns value in [0, 1] where 1 indicates healthy diversity.
 */
export function calculateSpectralEntropy(spectrum: number[]): number {
  if (spectrum.length === 0) return 0;

  // Normalize spectrum to probabilities
  const sum = spectrum.reduce((a, b) => a + Math.abs(b), 0);
  if (sum === 0) return 0;

  const probs = spectrum.map((v) => Math.abs(v) / sum);

  // Calculate Shannon entropy
  const entropy = -probs.reduce((sum, p) => {
    if (p === 0) return sum;
    return sum + p * Math.log2(p);
  }, 0);

  // Normalize to [0, 1] based on max possible entropy
  const maxEntropy = Math.log2(spectrum.length);
  return maxEntropy > 0 ? entropy / maxEntropy : 0;
}

/**
 * Calculate mythographic consistency using cosine similarity
 *
 * This is a placeholder - in production, you would:
 * 1. Embed remembrance.content using a text embedding model
 * 2. Compare with cluster centroids or historical embeddings
 * 3. Return cosine similarity as consistency score
 */
export function calculateMythographicConsistency(content: string): number {
  // Placeholder implementation
  // In production: embed content and compare with vault's myth profile
  return 0.7; // Default medium consistency
}

/**
 * Full RCS calculation from ResonanceEntry
 */
export function calculateRCSFromEntry(
  entry: ResonanceEntry,
  spectrum?: number[]
): { rcs: number; shine_index: number } {
  const entropy = spectrum ? calculateSpectralEntropy(spectrum) : 0.5;
  const mythConsistency = calculateMythographicConsistency(entry.remembrance.content);

  const rcs = calculateRCS(
    entry.resonance_signature.frequency,
    entry.witnesses,
    entropy,
    mythConsistency
  );

  const shine_index = calculateShineIndex(rcs);

  return { rcs, shine_index };
}
