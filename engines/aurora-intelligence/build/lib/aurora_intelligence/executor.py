"""
Executor — Action Module

Calculates rewards from actual routing outcomes and triggers Q-learning updates.
"""

from typing import Dict, Optional
from dataclasses import dataclass
import time
import uuid


@dataclass
class RoutingDecision:
    """Record of a routing decision."""
    decision_id: str
    state_key: str
    provider_id: str
    timestamp: float
    context: Dict
    metadata: Dict


@dataclass
class RoutingOutcome:
    """Actual outcome of a routing decision."""
    decision_id: str
    success: bool
    actual_cost_usd: float
    actual_latency_ms: float
    actual_reputation: Optional[float] = None
    error_reason: Optional[str] = None


class Executor:
    """
    Executes routing decisions and computes rewards.

    Maintains decision history for feedback loop.
    """

    def __init__(self):
        # Decision log: decision_id -> RoutingDecision
        self.decisions: Dict[str, RoutingDecision] = {}
        self.outcomes: Dict[str, RoutingOutcome] = {}

    def record_decision(
        self,
        state_key: str,
        provider_id: str,
        context: Dict,
        metadata: Dict,
    ) -> str:
        """
        Record a routing decision for future feedback.

        Returns:
            decision_id: Unique identifier for this decision
        """
        decision_id = str(uuid.uuid4())

        decision = RoutingDecision(
            decision_id=decision_id,
            state_key=state_key,
            provider_id=provider_id,
            timestamp=time.time(),
            context=context,
            metadata=metadata,
        )

        self.decisions[decision_id] = decision
        return decision_id

    def record_outcome(
        self,
        decision_id: str,
        success: bool,
        actual_cost_usd: float,
        actual_latency_ms: float,
        actual_reputation: Optional[float] = None,
        error_reason: Optional[str] = None,
    ) -> Optional[float]:
        """
        Record actual outcome of a routing decision and compute reward.

        Returns:
            reward: Computed reward value (or None if decision not found)
        """
        if decision_id not in self.decisions:
            return None

        outcome = RoutingOutcome(
            decision_id=decision_id,
            success=success,
            actual_cost_usd=actual_cost_usd,
            actual_latency_ms=actual_latency_ms,
            actual_reputation=actual_reputation,
            error_reason=error_reason,
        )

        self.outcomes[decision_id] = outcome

        # Compute reward
        reward = self.compute_reward(outcome)
        return reward

    def compute_reward(self, outcome: RoutingOutcome) -> float:
        """
        Compute reward from routing outcome.

        Reward function:
            reward = -cost + latency_penalty + reputation_bonus + success_bonus

        Normalization:
            - Cost: USD per hour (negative reward)
            - Latency: ms normalized to 0-1 penalty (0ms = 0, 500ms = -1)
            - Reputation: 0-100 normalized to 0-1 bonus
            - Success: +10 bonus for successful routing, -20 penalty for failure
        """
        if not outcome.success:
            # Heavy penalty for failure
            return -20.0

        # Cost penalty (USD per hour, negative)
        cost_penalty = -outcome.actual_cost_usd

        # Latency penalty (normalized to 0-1, higher is worse)
        latency_penalty = -(outcome.actual_latency_ms / 500.0)

        # Reputation bonus (0-100 normalized to 0-1)
        reputation_bonus = 0.0
        if outcome.actual_reputation is not None:
            reputation_bonus = outcome.actual_reputation / 100.0

        # Success bonus
        success_bonus = 10.0

        reward = cost_penalty + latency_penalty + reputation_bonus + success_bonus

        return reward

    def get_decision(self, decision_id: str) -> Optional[RoutingDecision]:
        """Retrieve a recorded decision."""
        return self.decisions.get(decision_id)

    def get_outcome(self, decision_id: str) -> Optional[RoutingOutcome]:
        """Retrieve a recorded outcome."""
        return self.outcomes.get(decision_id)

    def get_stats(self) -> Dict:
        """Get executor statistics."""
        total_decisions = len(self.decisions)
        total_outcomes = len(self.outcomes)

        if total_outcomes > 0:
            successful = sum(1 for o in self.outcomes.values() if o.success)
            success_rate = successful / total_outcomes
            avg_cost = sum(o.actual_cost_usd for o in self.outcomes.values()) / total_outcomes
            avg_latency = sum(o.actual_latency_ms for o in self.outcomes.values()) / total_outcomes
        else:
            success_rate = 0.0
            avg_cost = 0.0
            avg_latency = 0.0

        return {
            "total_decisions": total_decisions,
            "total_outcomes": total_outcomes,
            "success_rate": success_rate,
            "avg_cost_usd": avg_cost,
            "avg_latency_ms": avg_latency,
            "pending_feedback": total_decisions - total_outcomes,
        }
