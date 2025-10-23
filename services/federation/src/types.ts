export type BatchAnnounce = {
  namespace: string;
  batchId: string;
  batchRoot: `sha256:${string}`;
  anchors?: any[]; // AnchorAttestation[]
  ts: number;
  signer: string; // DID
  sig?: string;   // future: detached JWS
};

export type BundleRequest = {
  namespace: string;
  fromTs?: number;
  toTs?: number;
  want?: string[]; // receipt IDs or batchIds
  signer: string;
  ts: number;
};

export type Bundle = {
  receipts: any[]; // FinalReceipt[]
  anchors: any[];  // AnchorAttestation[]
  signer: string;
  ts: number;
};

export type PeerIdent = {
  did: string;
  url: string;
  roles: string[];
  keys?: { verify?: string };
};

export type NamespaceRoute = {
  peers: string[];
  verify?: { evm_confirmations?: number; btc_confirmations?: number };
  limits?: { max_announce_rate_per_min?: number };
};
