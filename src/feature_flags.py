"""Feature flags and kill switches for VaultMesh services."""
from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class FeatureFlags:
    federation_enabled: bool
    anchor_write_enabled: bool
    verify_enforce: bool

    @classmethod
    def from_env(cls) -> "FeatureFlags":
        return cls(
            federation_enabled=_env_flag("FEDERATION_ENABLED", default=False),
            anchor_write_enabled=_env_flag("ANCHOR_WRITE_ENABLED", default=False),
            verify_enforce=_env_flag("VERIFY_ENFORCE", default=True),
        )


def _env_flag(name: str, default: bool) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.lower() in {"1", "true", "yes", "on"}


__all__ = ["FeatureFlags", "_env_flag"]
