import { z } from 'zod';

/**
 * Treasury Flow Schema (VaultMesh v1.0)
 *
 * Tracks lumens (attention-energy) flow between vaults and system.
 * Used for economic analysis and Tem service rewards.
 */

export const TreasuryFlowSchema = z.object({
  flow_id: z.string().uuid(),
  from: z.string(), // did:vault:<id> or 'system'
  to: z.string(), // did:vault:<id> or 'system'
  lumens: z.number().min(0), // Attention-energy amount
  reason: z.enum(['witness', 'emission', 'tem_service', 'reward', 'penalty']),

  // Metadata
  timestamp: z.string().datetime().optional(),
  entry_ref: z.string().uuid().optional(), // Optional reference to ResonanceEntry
  action_ref: z.string().uuid().optional(), // Optional reference to TemAction
});

export type TreasuryFlow = z.infer<typeof TreasuryFlowSchema>;
