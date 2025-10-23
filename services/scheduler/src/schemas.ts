import { z } from 'zod';

export const CadenceSchema = z.object({
  target: z.string().regex(/^(eip155|btc|rfc3161):/),
  every: z.string().regex(/^(\d+(s|m|h|d)|\d+\*fast)$/i),
  confirmations: z.number().int().min(0).optional(),
  policyOID: z.string().optional(),
}).strict();

export const NamespaceSchema = z.object({
  description: z.string().optional(),
  witnesses: z.object({
    min_required: z.number().int().min(1),
    allowlist: z.array(z.string()),
  }).optional(),
  schema_policy: z.object({
    allow: z.array(z.string())
  }).optional(),
  cadence: z.object({
    fast: CadenceSchema,
    strong: CadenceSchema.optional(),
    cold: CadenceSchema.optional(),
  })
}).strict();

export const NamespacesConfigSchema = z.object({
  namespaces: z.record(z.string(), NamespaceSchema)
}).strict();

export type Cadence = z.infer<typeof CadenceSchema>;
export type NamespaceCfg = z.infer<typeof NamespaceSchema>;
export type NamespacesCfg = z.infer<typeof NamespacesConfigSchema>;

export type State = Record<string, { last: { fast?: number; strong?: number; cold?: number }, backoff?: number }>;

