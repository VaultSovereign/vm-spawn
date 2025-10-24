import { z } from 'zod';

/**
 * Vault Fingerprint Schema (VaultMesh v1.0)
 *
 * Represents the harmonic signature of a vault.
 * Used for identifying and clustering vaults by resonance patterns.
 */

export const VaultFingerprintSchema = z.object({
  vault: z.string().regex(/^did:vault:.+/), // did:vault:<id>
  harmonic_vector: z.array(z.number()).min(5).max(32), // 5-32 dimensions
  last_synced: z.string().datetime(), // ISO-8601

  // Derived metrics
  avg_coherence: z.number().min(0).max(1).optional(),
  avg_shine: z.number().min(0).max(1).optional(),
  primary_harmonic_tone: z.enum(['major', 'minor', 'neutral']).optional(),
});

export type VaultFingerprint = z.infer<typeof VaultFingerprintSchema>;
