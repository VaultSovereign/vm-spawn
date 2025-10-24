import { z } from 'zod';

/**
 * Lightframe Schema (VaultMesh v1.0)
 *
 * Derived artifact from a resonance entry.
 * Represents the spectral analysis and shine characteristics.
 */

export const LightframeSchema = z.object({
  entry_id: z.string().uuid(), // Reference to parent ResonanceEntry
  colorspace: z.enum(['gold', 'indigo', 'cyan', 'violet', 'silver']),
  shine_index: z.number().min(0).max(1), // 0..1
  spectrum: z.array(z.number()), // Spectral bins (floats)

  // Metadata
  created_at: z.string().datetime().optional(),
  vault_id: z.string().regex(/^did:vault:.+/).optional(),
});

export type Lightframe = z.infer<typeof LightframeSchema>;
