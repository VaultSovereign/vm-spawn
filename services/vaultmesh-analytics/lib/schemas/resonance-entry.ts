import { z } from 'zod';

/**
 * Resonance Entry Schema (VaultMesh v1.0)
 *
 * Represents a resonance event emitted by a vault, including:
 * - Frequency and harmonic tone
 * - Witnesses and their alignments
 * - Remembrance (mythographic content)
 * - Optional ZK proofs and signatures
 */

export const ResonanceSignatureSchema = z.object({
  frequency: z.number().min(0).max(2), // Hz or normalized [0,2]
  harmonic_tone: z.enum(['major', 'minor', 'neutral']),
  coherence_hint: z.number().min(0).max(1), // Self-declared coherence 0..1
});

export const RemembranceSchema = z.object({
  type: z.enum(['creation', 'connection', 'transformation', 'dissolution']),
  content: z.string(), // Mythographic text or URI
});

export const WitnessSchema = z.object({
  did: z.string().regex(/^did:vault:.+/), // did:vault:<id>
  alignment: z.number().min(0).max(1), // Witness alignment 0..1
});

export const ProofsSchema = z.object({
  zk_coherence: z.string().optional(), // Optional SNARK/STARK (bytes as hex)
  sig: z.string(), // Emitter signature (bytes as hex)
});

export const HashesSchema = z.object({
  meaning_blake3: z.string().regex(/^[0-9a-f]{64}$/), // BLAKE3 hash (hex)
});

export const ResonanceEntrySchema = z.object({
  id: z.string().uuid(),
  emitter: z.string().regex(/^did:vault:.+/), // did:vault:<id>
  timestamp: z.string().datetime(), // ISO-8601
  resonance_signature: ResonanceSignatureSchema,
  remembrance: RemembranceSchema,
  witnesses: z.array(WitnessSchema),
  proofs: ProofsSchema,
  hashes: HashesSchema,

  // Derived fields (computed by analytics)
  rcs: z.number().min(0).max(1).optional(), // Resonance Coherence Score
  shine_index: z.number().min(0).max(1).optional(), // Shine Index
});

// TypeScript types
export type ResonanceSignature = z.infer<typeof ResonanceSignatureSchema>;
export type Remembrance = z.infer<typeof RemembranceSchema>;
export type Witness = z.infer<typeof WitnessSchema>;
export type Proofs = z.infer<typeof ProofsSchema>;
export type Hashes = z.infer<typeof HashesSchema>;
export type ResonanceEntry = z.infer<typeof ResonanceEntrySchema>;
