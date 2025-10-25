"""
Auditor — Verification Module

Validates routing decisions against constraints and policy.
Logs audit trail for compliance and debugging.
"""

from typing import Dict, List, Optional
from dataclasses import dataclass
from enum import Enum
import time


class ViolationType(Enum):
    """Types of policy violations."""
    PRICE_EXCEEDED = "price_exceeded"
    LATENCY_EXCEEDED = "latency_exceeded"
    REPUTATION_TOO_LOW = "reputation_too_low"
    REGION_MISMATCH = "region_mismatch"
    GPU_TYPE_MISMATCH = "gpu_type_mismatch"
    INSUFFICIENT_CAPACITY = "insufficient_capacity"


@dataclass
class AuditEntry:
    """Single audit log entry."""
    timestamp: float
    decision_id: str
    state_key: str
    provider_id: str
    status: str  # "approved", "rejected", "flagged"
    violations: List[ViolationType]
    notes: Optional[str] = None


class Auditor:
    """
    Validates routing decisions and maintains audit trail.

    Ensures decisions comply with:
    - Budget constraints
    - Latency SLAs
    - Provider reputation requirements
    - Regional restrictions
    - Capacity limits
    """

    def __init__(self, strict_mode: bool = False):
        self.strict_mode = strict_mode
        self.audit_log: List[AuditEntry] = []

    def validate_decision(
        self,
        decision_id: str,
        state_key: str,
        provider_id: str,
        provider_state: Dict,
        constraints: Dict,
    ) -> tuple[bool, List[ViolationType]]:
        """
        Validate a routing decision against constraints.

        Args:
            decision_id: Decision identifier
            state_key: Q-learning state key
            provider_id: Selected provider
            provider_state: Provider capabilities and current state
            constraints: User-defined constraints (max_price, max_latency, etc.)

        Returns:
            (is_valid, violations): Tuple of validation status and list of violations
        """
        violations = []

        # Price constraint
        max_price = constraints.get("max_price")
        if max_price is not None and provider_state.get("price_usd_per_hour", 0) > max_price:
            violations.append(ViolationType.PRICE_EXCEEDED)

        # Latency constraint
        max_latency = constraints.get("max_latency_ms")
        if max_latency is not None and provider_state.get("latency_ms", 0) > max_latency:
            violations.append(ViolationType.LATENCY_EXCEEDED)

        # Reputation constraint
        min_reputation = constraints.get("min_reputation")
        if min_reputation is not None and provider_state.get("reputation", 0) < min_reputation:
            violations.append(ViolationType.REPUTATION_TOO_LOW)

        # Region constraint
        required_region = constraints.get("region")
        if required_region and required_region not in provider_state.get("regions", []):
            violations.append(ViolationType.REGION_MISMATCH)

        # GPU type constraint
        required_gpu = constraints.get("gpu_type")
        if required_gpu and required_gpu not in provider_state.get("gpu_types", []):
            violations.append(ViolationType.GPU_TYPE_MISMATCH)

        # Capacity constraint
        required_capacity = constraints.get("gpu_hours", 0)
        if provider_state.get("capacity_available", float('inf')) < required_capacity:
            violations.append(ViolationType.INSUFFICIENT_CAPACITY)

        # Determine status
        if not violations:
            status = "approved"
        elif self.strict_mode:
            status = "rejected"
        else:
            status = "flagged"

        # Log audit entry
        entry = AuditEntry(
            timestamp=time.time(),
            decision_id=decision_id,
            state_key=state_key,
            provider_id=provider_id,
            status=status,
            violations=violations,
        )
        self.audit_log.append(entry)

        is_valid = status != "rejected"
        return is_valid, violations

    def flag_anomaly(
        self,
        decision_id: str,
        state_key: str,
        provider_id: str,
        reason: str,
    ):
        """
        Flag a decision for anomalous behavior.

        Examples:
        - Q-value sudden spike
        - Provider consistently underperforming
        - Unusual exploration pattern
        """
        entry = AuditEntry(
            timestamp=time.time(),
            decision_id=decision_id,
            state_key=state_key,
            provider_id=provider_id,
            status="flagged",
            violations=[],
            notes=f"ANOMALY: {reason}",
        )
        self.audit_log.append(entry)

    def get_audit_trail(
        self,
        decision_id: Optional[str] = None,
        limit: int = 100,
    ) -> List[AuditEntry]:
        """
        Retrieve audit trail.

        Args:
            decision_id: Optional filter by decision ID
            limit: Maximum entries to return

        Returns:
            List of audit entries (most recent first)
        """
        if decision_id:
            entries = [e for e in self.audit_log if e.decision_id == decision_id]
        else:
            entries = self.audit_log

        return list(reversed(entries))[-limit:]

    def get_stats(self) -> Dict:
        """Get auditor statistics."""
        total_entries = len(self.audit_log)

        if total_entries == 0:
            return {
                "total_entries": 0,
                "approval_rate": 0.0,
                "rejection_rate": 0.0,
                "flagged_rate": 0.0,
                "common_violations": [],
            }

        approved = sum(1 for e in self.audit_log if e.status == "approved")
        rejected = sum(1 for e in self.audit_log if e.status == "rejected")
        flagged = sum(1 for e in self.audit_log if e.status == "flagged")

        # Count violation types
        violation_counts: Dict[ViolationType, int] = {}
        for entry in self.audit_log:
            for violation in entry.violations:
                violation_counts[violation] = violation_counts.get(violation, 0) + 1

        common_violations = sorted(
            violation_counts.items(),
            key=lambda x: x[1],
            reverse=True,
        )[:5]

        return {
            "total_entries": total_entries,
            "approval_rate": approved / total_entries,
            "rejection_rate": rejected / total_entries,
            "flagged_rate": flagged / total_entries,
            "common_violations": [
                {"type": v.value, "count": c}
                for v, c in common_violations
            ],
        }
