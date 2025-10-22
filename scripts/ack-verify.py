#!/usr/bin/env python3
"""
ACK signature verification for Aurora treaty responses.
Verifies that provider ACKs are properly signed.
"""

import base64
import json
import os
import sys
from pathlib import Path
from typing import Dict, Optional, Tuple

try:
    from cryptography.hazmat.primitives.asymmetric import ed25519
    from cryptography.hazmat.primitives import serialization
    from jsonschema import validate, ValidationError
    CRYPTO_AVAILABLE = True
except ImportError:
    CRYPTO_AVAILABLE = False
    print("[error] Required libraries not installed", file=sys.stderr)
    print("[error] Install: pip install cryptography jsonschema", file=sys.stderr)
    sys.exit(1)


class ProviderKeyRegistry:
    """Registry of provider public keys by treaty ID."""

    def __init__(self, keys_dir: str = "secrets/provider-keys"):
        self.keys_dir = Path(keys_dir)
        self._cache = {}

    def load_key(self, treaty_id: str, provider_id: str) -> Optional[ed25519.Ed25519PublicKey]:
        """
        Load provider public key for treaty.

        Key file naming convention:
        secrets/provider-keys/{treaty_id}/{provider_id}.pub
        Example: secrets/provider-keys/AURORA-AKASH-001/akash-main.pub
        """
        cache_key = f"{treaty_id}:{provider_id}"
        if cache_key in self._cache:
            return self._cache[cache_key]

        key_path = self.keys_dir / treaty_id / f"{provider_id}.pub"
        if not key_path.exists():
            print(f"[warning] Provider key not found: {key_path}", file=sys.stderr)
            return None

        try:
            with open(key_path, 'rb') as f:
                public_key = serialization.load_pem_public_key(f.read())
                if isinstance(public_key, ed25519.Ed25519PublicKey):
                    self._cache[cache_key] = public_key
                    return public_key
                else:
                    print(f"[error] Invalid key type in {key_path}", file=sys.stderr)
                    return None
        except Exception as e:
            print(f"[error] Failed to load key {key_path}: {e}", file=sys.stderr)
            return None


class AckVerifier:
    """Verify ACK messages from providers."""

    def __init__(self, registry: ProviderKeyRegistry, schema_path: Optional[str] = None):
        self.registry = registry
        self.schema_path = schema_path or "schemas/axelar-ack.schema.json"
        self.schema = None

        # Load ACK schema if available
        if Path(self.schema_path).exists():
            try:
                with open(self.schema_path) as f:
                    self.schema = json.load(f)
            except Exception as e:
                print(f"[warning] Failed to load ACK schema: {e}", file=sys.stderr)

    def verify(self, ack: Dict, treaty_id: str, provider_id: str) -> Tuple[bool, str]:
        """
        Verify ACK signature and schema.

        Args:
            ack: ACK message dict
            treaty_id: Treaty ID (e.g., "AURORA-AKASH-001")
            provider_id: Provider ID (e.g., "akash-main")

        Returns:
            (valid, reason) tuple
        """
        # 1. Schema validation
        if self.schema:
            try:
                validate(ack, self.schema)
            except ValidationError as e:
                return False, f"schema validation failed: {e.message}"

        # 2. Check required fields
        if "signature" not in ack:
            return False, "missing signature field"
        if "ack_id" not in ack:
            return False, "missing ack_id field"

        # 3. Load provider public key
        public_key = self.registry.load_key(treaty_id, provider_id)
        if not public_key:
            return False, f"provider public key not found for {provider_id}"

        # 4. Verify signature
        try:
            signature_b64 = ack["signature"]
            signature = base64.b64decode(signature_b64)

            # Canonical JSON (sorted keys, no whitespace)
            canonical_data = {k: v for k, v in ack.items() if k != "signature"}
            canonical_json = json.dumps(canonical_data, separators=(",", ":"), sort_keys=True).encode()

            public_key.verify(signature, canonical_json)
            return True, "ok"

        except base64.binascii.Error:
            return False, "invalid base64 signature"
        except Exception as e:
            return False, f"signature verification failed: {e}"


# CLI for testing
if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Verify ACK signatures")
    parser.add_argument("ack_file", help="Path to ACK JSON file")
    parser.add_argument("--treaty-id", required=True, help="Treaty ID")
    parser.add_argument("--provider-id", required=True, help="Provider ID")
    parser.add_argument("--keys-dir", default="secrets/provider-keys", help="Provider keys directory")
    parser.add_argument("--schema", help="ACK schema path (default: schemas/axelar-ack.schema.json)")
    args = parser.parse_args()

    # Load ACK
    try:
        with open(args.ack_file) as f:
            ack = json.load(f)
    except Exception as e:
        print(f"Error loading ACK file: {e}", file=sys.stderr)
        sys.exit(1)

    # Verify
    registry = ProviderKeyRegistry(args.keys_dir)
    verifier = AckVerifier(registry, args.schema)
    valid, reason = verifier.verify(ack, args.treaty_id, args.provider_id)

    print(f"ACK ID: {ack.get('ack_id', 'N/A')}")
    print(f"Treaty ID: {args.treaty_id}")
    print(f"Provider ID: {args.provider_id}")
    print(f"Valid: {valid}")
    print(f"Reason: {reason}")

    sys.exit(0 if valid else 1)
