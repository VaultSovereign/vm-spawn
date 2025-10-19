#!/usr/bin/env python3
"""
Federation Foundations (v4.0 Kickoff MVP)
- Projection model
- Config loader
- MerkleDiff/MemoryValidator stubs
"""
from __future__ import annotations
from dataclasses import dataclass
from typing import Dict, List, Optional
import json, os, yaml
import subprocess

@dataclass
class MemoryProjection:
    node_id: str
    timestamp: str
    merkle_root: str
    memory_count: int
    signatures: List[str]
    vector_clock: Dict[str, int]

class FederationConfig:
    def __init__(self, config_path: str):
        self.path = config_path
        self.node_id: str = ""
        self.peers: List[Dict] = []
        self.sync_interval: int = 60
        self.retry_backoff: List[int] = [5, 10, 30]
        self.trust: Dict[str, object] = {"require_signatures": True, "min_quorum": 2}
        if os.path.isfile(config_path):
            data = yaml.safe_load(open(config_path, "r", encoding="utf-8")) or {}
            self.node_id = data.get("node_id", "")
            self.peers = data.get("peers", [])
            sync = data.get("sync", {})
            self.sync_interval = int(sync.get("interval_seconds", 60))
            self.retry_backoff = list(sync.get("retry_backoff", [5, 10, 30]))
            self.trust = data.get("trust", self.trust)

class MerkleDiff:
    @staticmethod
    def compute_diff(local_ids: List[str], remote_ids: List[str]) -> List[str]:
        """
        Return IDs that exist on remote but not locally (simple, robust MVP).
        Optimize later with frontier snapshots / Merkle projection.
        """
        lset = set(local_ids)
        return [mid for mid in remote_ids if mid not in lset]

class MemoryValidator:
    def __init__(self, trust_anchors: Dict[str, str], config_path: str = None):
        """
        trust_anchors: node_id -> path to GPG pubkey (future use)
        config_path: optional path to federation.yaml for policy toggles
        """
        self.trust_anchors = trust_anchors
        self.require_signatures = False
        # Load federation config (optional)
        cfg_path = config_path or os.path.join(os.path.dirname(__file__), "..", "data", "federation.yaml")
        cfg_path = os.path.abspath(cfg_path)
        try:
            if os.path.isfile(cfg_path):
                cfg = yaml.safe_load(open(cfg_path, "r", encoding="utf-8")) or {}
                trust = (cfg.get("trust") or {})
                self.require_signatures = bool(trust.get("require_signatures", False))
        except Exception:
            # Fail-permissive if we cannot read config
            self.require_signatures = False
    def verify_memory(self, memory: Dict, node_id: str) -> bool:
        """
        Validate a memory:
          - If 'sig' present and 'data' includes 'artifact' and 'sig_file', verify GPG (detached).
          - If 'data' includes 'tsr' token, verify RFC3161 if TSA CA is available.
        All checks are best-effort; return False on hard failures.
        Strict mode: if require_signatures is true, enforce valid GPG signature for artifact-like memories.
        """
        try:
            # GPG verification (optional)
            art = None
            sig_file = None
            data = memory.get("data") or {}
            if isinstance(data, str):
                try:
                    data = json.loads(data)
                except Exception:
                    data = {}
            art = data.get("artifact")
            sig_file = data.get("sig") or data.get("sig_file")

            # Determine if this memory should be signature-enforced in strict mode.
            # Heuristic: enforce for artifact-like or deployment-like entries.
            mtype = (memory.get("type") or "").lower()
            enforce = self.require_signatures and (bool(art) or mtype in {"artifact", "deployment", "release"})

            if art and sig_file and os.path.isfile(art) and os.path.isfile(sig_file):
                g = subprocess.run(["gpg","--verify",sig_file,art], text=True, capture_output=True)
                if g.returncode != 0:
                    # Invalid signature is always a failure
                    return False

            # RFC3161 timestamp (optional)
            tsr = data.get("tsr") or data.get("token_file")
            ca  = os.getenv("FREETSA_CA") or os.path.join("ops","certs","freetsa-ca.pem")
            if art and tsr and os.path.isfile(tsr) and os.path.isfile(art) and os.path.isfile(ca):
                t = subprocess.run(["openssl","ts","-verify","-data",art,"-in",tsr,"-CAfile",ca],
                                   text=True, capture_output=True)
                if t.returncode != 0:
                    # Timestamp failure does not block unless required in future policy.
                    # Keep permissive to avoid false negatives when CA not deployed.
                    pass

            # If strict mode demands a signature but we never validated one (missing files),
            # treat as failure for artifact/deployment memories.
            if enforce and not (art and sig_file and os.path.isfile(art) and os.path.isfile(sig_file)):
                return False

            return True
        except Exception:
            return False

