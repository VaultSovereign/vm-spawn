#!/usr/bin/env python3
import os, json, base64, datetime
from dataclasses import dataclass, asdict
from typing import Dict, Any, Optional, List

from blake3 import blake3
from cryptography.hazmat.primitives.ciphers.aead import XChaCha20Poly1305
from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey, Ed25519PublicKey
)
from cryptography.hazmat.primitives import serialization

# ---------- helpers ----------
def iso_now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def canonical_bytes(obj: Any) -> bytes:
    return json.dumps(obj, separators=(",", ":"), sort_keys=True).encode("utf-8")

def b64e(b: bytes) -> str:
    return base64.b64encode(b).decode("ascii")

def b64d(s: str) -> bytes:
    return base64.b64decode(s.encode("ascii"))

# ---------- append-only ledger (immutable log) ----------
class Ledger:
    def __init__(self) -> None:
        self.entries: List[Dict[str, Any]] = []

    def append_anchor(self, record_id: str, blob_hash: str, policy_tags: List[str], key_ref: str) -> Dict[str, Any]:
        entry = {
            "seq": len(self.entries),
            "type": "anchor",
            "record_id": record_id,
            "blob_hash": blob_hash,
            "policy": policy_tags,
            "key_ref": key_ref,
            "ts": iso_now(),
        }
        self.entries.append(entry)
        return entry

    def append_receipt_digest(self, record_id: str, receipt_canonical: bytes) -> Dict[str, Any]:
        digest = blake3(receipt_canonical).hexdigest()
        entry = {
            "seq": len(self.entries),
            "type": "receipt",
            "record_id": record_id,
            "receipt_digest": digest,
            "ts": iso_now(),
        }
        self.entries.append(entry)
        return entry

    def last_anchor(self, record_id: str) -> Optional[Dict[str, Any]]:
        for e in reversed(self.entries):
            if e["type"] == "anchor" and e["record_id"] == record_id:
                return e
        return None

# ---------- tiny in-memory "KMS" for demo ----------
class KeyStore:
    """
    Stores per-record data-encryption keys (DEKs) wrapped under an in-memory KEK.
    In production, use a real KMS/HSM and call its destroy API.
    """
    def __init__(self) -> None:
        self._kek = os.urandom(32)  # KEK
        self._store: Dict[str, bytes] = {}  # record_id -> wrap(nonce || ct)

    def wrap_and_store(self, record_id: str, kr: bytes) -> str:
        aead = XChaCha20Poly1305(self._kek)
        nonce = os.urandom(24)
        ct = aead.encrypt(nonce, kr, associated_data=record_id.encode())
        self._store[record_id] = nonce + ct
        # Opaque reference you would log/anchor for auditability
        return f"kms://local/{record_id}#v1"

    def unwrap(self, record_id: str) -> Optional[bytes]:
        blob = self._store.get(record_id)
        if blob is None:
            return None
        aead = XChaCha20Poly1305(self._kek)
        nonce, ct = blob[:24], blob[24:]
        return aead.decrypt(nonce, ct, associated_data=record_id.encode())

    def destroy(self, record_id: str) -> None:
        if record_id in self._store:
            del self._store[record_id]

# ---------- signer for receipts ----------
class ServiceSigner:
    def __init__(self) -> None:
        self.sk = Ed25519PrivateKey.generate()
        self.pk = self.sk.public_key()

    @property
    def pub_b64(self) -> str:
        raw = self.pk.public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw,
        )
        return b64e(raw)

    def sign(self, msg: bytes) -> str:
        return b64e(self.sk.sign(msg))

    @staticmethod
    def verify(pub_b64: str, msg: bytes, sig_b64: str) -> None:
        pub = Ed25519PublicKey.from_public_bytes(b64d(pub_b64))
        pub.verify(b64d(sig_b64), msg)  # raises on failure

# ---------- erasure receipt ----------
@dataclass
class ErasureReceipt:
    record_id: str
    anchor_blob_hash: str
    key_ref: str
    lawful_basis: str
    ts: str
    issuer: str
    pubkey: str
    signature: str  # base64 over canonical JSON of receipt without signature

    @staticmethod
    def unsigned(record_id: str, anchor_blob_hash: str, key_ref: str, lawful_basis: str, issuer: str, pubkey: str) -> Dict[str, str]:
        return {
            "record_id": record_id,
            "anchor_blob_hash": anchor_blob_hash,
            "key_ref": key_ref,
            "lawful_basis": lawful_basis,
            "ts": iso_now(),
            "issuer": issuer,
            "pubkey": pubkey,
        }

# ---------- demo engine ----------
class CryptoShredDemo:
    def __init__(self) -> None:
        self.ledger = Ledger()
        self.kms = KeyStore()
        self.signer = ServiceSigner()
        self.blob_store: Dict[str, bytes] = {}  # record_id -> sealed blob (nonce||ct)

    @staticmethod
    def _aad(record_id: str, policy_tags: List[str]) -> bytes:
        # Bind identity/policy into AEAD so swaps/tampering are detectable
        return canonical_bytes({"record_id": record_id, "policy": policy_tags})

    @staticmethod
    def _seal(kr: bytes, plaintext: bytes, aad: bytes) -> bytes:
        aead = XChaCha20Poly1305(kr)
        nonce = os.urandom(24)
        ct = aead.encrypt(nonce, plaintext, aad)
        return nonce + ct  # store nonce inline for simplicity

    @staticmethod
    def _open(kr: bytes, sealed: bytes, aad: bytes) -> bytes:
        aead = XChaCha20Poly1305(kr)
        nonce, ct = sealed[:24], sealed[24:]
        return aead.decrypt(nonce, ct, aad)

    def write_record(self, record_id: str, pii: Dict[str, Any], policy_tags: List[str]) -> Dict[str, Any]:
        kr = os.urandom(32)  # per-record key
        aad = self._aad(record_id, policy_tags)
        sealed = self._seal(kr, canonical_bytes(pii), aad)
        blob_hash = blake3(sealed).hexdigest()

        key_ref = self.kms.wrap_and_store(record_id, kr)
        self.blob_store[record_id] = sealed
        anchor = self.ledger.append_anchor(record_id, blob_hash, policy_tags, key_ref)
        return anchor

    def read_record(self, record_id: str, policy_tags: List[str]) -> Dict[str, Any]:
        kr = self.kms.unwrap(record_id)
        if kr is None:
            raise RuntimeError("Record key not found (likely erased).")
        sealed = self.blob_store[record_id]
        aad = self._aad(record_id, policy_tags)
        pt = self._open(kr, sealed, aad)
        return json.loads(pt.decode("utf-8"))

    def read_proof(self, record_id: str) -> bool:
        """Prove the blob matches its immutable anchor."""
        sealed = self.blob_store[record_id]
        h = blake3(sealed).hexdigest()
        anchor = self.ledger.last_anchor(record_id)
        return anchor is not None and anchor["blob_hash"] == h

    def erase_record(self, record_id: str, lawful_basis: str, issuer: str = "DemoService v1") -> ErasureReceipt:
        anchor = self.ledger.last_anchor(record_id)
        if anchor is None:
            raise RuntimeError("No anchor found for record.")

        # Destroy only the per-record key (ciphertext remains)
        self.kms.destroy(record_id)

        unsigned = ErasureReceipt.unsigned(
            record_id=record_id,
            anchor_blob_hash=anchor["blob_hash"],
            key_ref=anchor["key_ref"],
            lawful_basis=lawful_basis,
            issuer=issuer,
            pubkey=self.signer.pub_b64,
        )
        msg = canonical_bytes(unsigned)
        sig = self.signer.sign(msg)
        receipt = ErasureReceipt(signature=sig, **unsigned)

        # Anchor receipt digest on the immutable log
        self.ledger.append_receipt_digest(record_id, msg)
        return receipt

    @staticmethod
    def verify_receipt(ledger: Ledger, receipt: ErasureReceipt) -> None:
        # 1) Verify signature over canonical unsigned JSON
        unsigned = {
            k: getattr(receipt, k)
            for k in ["record_id", "anchor_blob_hash", "key_ref", "lawful_basis", "ts", "issuer", "pubkey"]
        }
        msg = canonical_bytes(unsigned)
        ServiceSigner.verify(receipt.pubkey, msg, receipt.signature)

        # 2) Verify receipt digest was anchored
        digest = blake3(msg).hexdigest()
        anchored = any(
            e.get("type") == "receipt"
            and e.get("record_id") == receipt.record_id
            and e.get("receipt_digest") == digest
            for e in ledger.entries
        )
        if not anchored:
            raise RuntimeError("Receipt not anchored on immutable log.")

# ---------- example usage ----------
if __name__ == "__main__":
    demo = CryptoShredDemo()
    record_id = "user-123"
    policy = ["gdpr", "pii", "consent"]

    print("→ Write:")
    anchor = demo.write_record(record_id, {"name": "Ada", "email": "ada@example.com"}, policy)
    print(json.dumps(anchor, indent=2))

    print("\n→ Read (pre-erasure):")
    print(demo.read_record(record_id, policy))

    print("\n→ ReadProof (pre-erasure):", demo.read_proof(record_id))

    print("\n→ Erase by destroying per-record key:")
    receipt = demo.erase_record(record_id, lawful_basis="GDPR Art.17(1) – consent withdrawn")
    print(json.dumps(asdict(receipt), indent=2))

    print("\n→ Verify receipt:")
    CryptoShredDemo.verify_receipt(demo.ledger, receipt)
    print("Receipt signature + anchoring: OK")

    print("\n→ Read (post-erasure, expected failure):")
    try:
        demo.read_record(record_id, policy)
    except Exception as e:
        print("Decryption failed as expected:", str(e))

    print("\n→ ReadProof (ciphertext still anchored):", demo.read_proof(record_id))

