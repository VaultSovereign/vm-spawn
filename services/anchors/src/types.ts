export type AnchorInput = {
  batchId: string;
  batchRoot: `sha256:${string}`;
  chain: string;
  meta?: Record<string, unknown>;
};

export type AnchorAttestation = {
  chain: string;
  contract?: string;
  tx: string;
  block: number;
  ts: number;
  sig?: string;
  memo?: string;
};

export type AnchorResult = { anchor: AnchorAttestation };

export interface AnchorWriter {
  write(input: AnchorInput): Promise<AnchorResult>;
}

export interface AnchorVerifier {
  verify(anchor: AnchorAttestation, expectedRoot: `sha256:${string}`): Promise<{ ok: boolean; reason?: string }>;
}
