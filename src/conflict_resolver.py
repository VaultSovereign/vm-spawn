"""Deterministic conflict resolution for VaultMesh receipts."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Iterable, Mapping, Optional


_CHAIN_PRIORITY = {"BTC": 0, "EVM": 1, "TSA": 2}
_UNKNOWN_CHAIN_RANK = len(_CHAIN_PRIORITY)


def _to_aware_utc(value: object) -> datetime:
    """Convert the provided timestamp into an aware UTC datetime."""

    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)

    if isinstance(value, str):
        try:
            dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            dt = None
        if dt is not None:
            return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)

    return datetime.min.replace(tzinfo=timezone.utc)


@dataclass(frozen=True)
class ReceiptView:
    """Normalized view over receipt payloads used for ordering."""

    raw: Mapping[str, object]

    @property
    def chain_priority(self) -> int:
        chain = str(self.raw.get("chain", "")).upper()
        return _CHAIN_PRIORITY.get(chain, _UNKNOWN_CHAIN_RANK)

    @property
    def anchor_ts(self) -> datetime:
        value = self.raw.get("anchorTs") or self.raw.get("anchor_ts")
        return _to_aware_utc(value)

    @property
    def tx_hash(self) -> str:
        candidate = (
            self.raw.get("txHash")
            or self.raw.get("tx_hash")
            or self.raw.get("txRef")
            or self.raw.get("tx_ref")
            or ""
        )
        return str(candidate).lower()


def resolve(receipts: Iterable[Mapping[str, object]]) -> Optional[Mapping[str, object]]:
    """Return the winning receipt according to the canonical policy.

    The policy is:
    1. Prefer receipts by chain priority **BTC > EVM > TSA**.
    2. If chains match, choose the earliest ``anchor_ts``/``anchorTs`` timestamp.
    3. If still tied, choose the lowest ``tx_hash`` lexicographically.
    """

    normalized = [ReceiptView(raw=receipt) for receipt in receipts]
    if not normalized:
        return None

    normalized.sort(
        key=lambda view: (
            view.chain_priority,
            view.anchor_ts,
            view.tx_hash.lower(),
        )
    )
    return normalized[0].raw


__all__ = ["resolve"]
