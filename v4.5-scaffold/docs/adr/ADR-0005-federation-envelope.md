# ADR-0005 — Signed Receipt Envelope & Federation Topic
Status: PROPOSED

Use a JCS-serialized envelope for signing, timestamping, and gossip.

Envelope (JCS before signing):
{
  "schema": "vaultmesh.receipt.v1",
  "receipt": { /* Receipt */ },
  "merkle_root": "hex-32",
  "sig": { "alg": "openpgp-ed25519", "keyid": "....", "signature": "base64..." },
  "tsa": { "tsr_der": "base64..." }
}
Gossip: topic `vm/receipts/v1`; discovery Kademlia; transport Noise; merge = JCS bytes → Merkle.
