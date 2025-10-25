"""
Auditor - Computes rewards and updates Q-learning agent

The Auditor closes the learning loop by:
1. Computing reward from observed outcomes
2. Updating the Q-table based on (state, action, reward, next_state)
3. Persisting decision traces for observability
"""

from typing import Dict, Any
from ..models import FeedbackOutcome


def compute_reward(outcome: FeedbackOutcome) -> float:
    """
    Compute reward from observed outcome metrics

    Reward function balances multiple objectives:
    - Latency: Lower is better (target: <100ms)
    - Cost: Lower is better (target: <$1/hr)
    - SLO Hit: Boolean success indicator
    - Failures: Penalize errors

    Args:
        outcome: Feedback outcome with metrics

    Returns:
        Reward in range [-1.0, 1.0]
    """
    reward = 0.0

    # Latency component (weight: 0.4)
    if outcome.latency_ms is not None:
        # Target: <100ms = 1.0, >500ms = -1.0
        lat_score = (200 - outcome.latency_ms) / 200
        lat_score = max(-1.0, min(1.0, lat_score))
        reward += 0.4 * lat_score

    # Cost component (weight: 0.3)
    if outcome.cost is not None:
        # Target: <$0.50 = 1.0, >$2.00 = -1.0
        cost_score = (1.0 - outcome.cost) / 1.0
        cost_score = max(-1.0, min(1.0, cost_score))
        reward += 0.3 * cost_score

    # SLO component (weight: 0.2)
    if outcome.slo_hit is not None:
        slo_score = 1.0 if outcome.slo_hit else -0.5
        reward += 0.2 * slo_score

    # Failure penalty (weight: 0.1)
    if outcome.failures is not None and outcome.failures > 0:
        failure_penalty = -min(1.0, outcome.failures / 3)
        reward += 0.1 * failure_penalty
    else:
        reward += 0.1  # No failures = bonus

    # Clamp to [-1, 1]
    return max(-1.0, min(1.0, reward))


def explain_reward(outcome: FeedbackOutcome, reward: float) -> Dict[str, Any]:
    """
    Generate human-readable reward explanation

    Args:
        outcome: Feedback outcome
        reward: Computed reward

    Returns:
        Explanation dict with component breakdown
    """
    components = {}

    if outcome.latency_ms is not None:
        components["latency_score"] = (200 - outcome.latency_ms) / 200
        components["latency_ms"] = outcome.latency_ms

    if outcome.cost is not None:
        components["cost_score"] = (1.0 - outcome.cost) / 1.0
        components["cost_usd"] = outcome.cost

    if outcome.slo_hit is not None:
        components["slo_hit"] = outcome.slo_hit

    if outcome.failures is not None:
        components["failures"] = outcome.failures

    return {
        "total_reward": reward,
        "components": components,
        "explanation": _generate_explanation_text(outcome, reward)
    }


def _generate_explanation_text(outcome: FeedbackOutcome, reward: float) -> str:
    """Generate natural language explanation"""
    if reward > 0.5:
        return "Excellent outcome: low latency, low cost, SLO met"
    elif reward > 0:
        return "Good outcome: met most objectives"
    elif reward > -0.5:
        return "Marginal outcome: some objectives missed"
    else:
        return "Poor outcome: high latency/cost or SLO violation"
