import { z } from 'zod';

/**
 * Tem Action Schema (VaultMesh v1.0)
 *
 * Guardian intervention events (alchemical transmutations).
 * Tracks Nigredo, Albedo, Citrinitas, and Rubedo actions.
 */

export const TemActionSchema = z.object({
  action_id: z.string().uuid(),
  cause: z.enum(['anomaly', 'incoherence', 'attack']),
  playbook: z.enum(['nigredo', 'albedo', 'citrinitas', 'rubedo']),
  result: z.enum(['transmuted', 'quarantined', 'dismissed']),
  refs: z.array(z.string().uuid()), // Referenced entry IDs

  // Metadata
  timestamp: z.string().datetime().optional(),
  guardian_agent: z.string().optional(),
  reason: z.string().optional(),
});

export type TemAction = z.infer<typeof TemActionSchema>;

/**
 * Playbook Descriptions:
 *
 * - Nigredo: Dissolution of harmful patterns (detect incoherence spikes)
 * - Albedo: Purification in mirror-sandbox (isolate and gather counter-witness)
 * - Citrinitas: Transformation (propose reinterpretation, merge, ritual replay)
 * - Rubedo: Integration (publish transmutation, credit lumens to participants)
 */
