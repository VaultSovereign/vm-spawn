"""
Strategist — Planning Module

Implements Q-learning with ε-greedy exploration for adaptive routing decisions.
Reads Ψ-field consciousness metrics to adjust exploration/exploitation balance.
"""

import random
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
import json


@dataclass
class WorkloadContext:
    """Workload request context."""
    workload_type: str  # llm_inference, llm_training, rendering, general
    gpu_type: str       # a100, h100, a6000, 4090, t4, l40
    region: str
    gpu_hours: float
    max_price: Optional[float] = None
    max_latency_ms: Optional[float] = None
    min_reputation: Optional[float] = None


@dataclass
class ProviderState:
    """Provider state representation."""
    provider_id: str
    price_usd_per_hour: float
    latency_ms: float
    reputation: float  # 0-100
    capacity_available: float
    gpu_types: List[str]
    regions: List[str]


class Strategist:
    """
    Q-learning agent for adaptive routing decisions.

    State: (workload_type, gpu_type, region, provider)
    Action: Choose provider (akash, ionet, render, vast, etc.)
    Reward: -cost + latency_penalty + reputation_bonus
    """

    def __init__(
        self,
        epsilon: float = 0.1,
        epsilon_decay: float = 0.995,
        epsilon_min: float = 0.01,
        alpha: float = 0.1,  # Learning rate
        gamma: float = 0.95,  # Discount factor
    ):
        self.epsilon = epsilon
        self.epsilon_decay = epsilon_decay
        self.epsilon_min = epsilon_min
        self.alpha = alpha
        self.gamma = gamma

        # Q-table: state_key -> {provider_id: q_value}
        self.q_table: Dict[str, Dict[str, float]] = {}

        # Historical rewards for analysis
        self.reward_history: List[float] = []
        self.decision_count = 0

    def _state_key(self, context: WorkloadContext) -> str:
        """Convert workload context to Q-table state key."""
        return f"{context.workload_type}:{context.gpu_type}:{context.region}"

    def _initialize_state(self, state_key: str, providers: List[ProviderState]):
        """Initialize Q-values for new state."""
        if state_key not in self.q_table:
            self.q_table[state_key] = {
                p.provider_id: 0.0 for p in providers
            }

    def recommend(
        self,
        context: WorkloadContext,
        providers: List[ProviderState],
        psi_density: Optional[float] = None,
    ) -> Tuple[str, Dict]:
        """
        Recommend optimal provider using ε-greedy Q-learning.

        Args:
            context: Workload request context
            providers: Available providers matching constraints
            psi_density: Optional Ψ-field consciousness density (0-1)
                        Higher density → more exploitation (lower ε)

        Returns:
            (provider_id, metadata)
        """
        if not providers:
            return None, {"reason": "no_viable_providers"}

        state_key = self._state_key(context)
        self._initialize_state(state_key, providers)

        # Adjust epsilon based on Ψ-field consciousness
        effective_epsilon = self.epsilon
        if psi_density is not None:
            # High consciousness → low exploration (more confident)
            effective_epsilon = self.epsilon * (1 - psi_density * 0.5)

        # ε-greedy action selection
        if random.random() < effective_epsilon:
            # Explore: random provider
            provider = random.choice(providers)
            mode = "explore"
        else:
            # Exploit: best Q-value
            q_values = self.q_table[state_key]
            best_provider_id = max(q_values, key=q_values.get)
            provider = next(p for p in providers if p.provider_id == best_provider_id)
            mode = "exploit"

        self.decision_count += 1

        metadata = {
            "state_key": state_key,
            "mode": mode,
            "epsilon": effective_epsilon,
            "q_value": self.q_table[state_key][provider.provider_id],
            "decision_count": self.decision_count,
            "psi_adjusted": psi_density is not None,
        }

        return provider.provider_id, metadata

    def update_q_value(
        self,
        state_key: str,
        provider_id: str,
        reward: float,
        next_state_key: Optional[str] = None,
    ):
        """
        Update Q-value using Bellman equation.

        Q(s,a) ← Q(s,a) + α[r + γ·max Q(s',a') - Q(s,a)]
        """
        if state_key not in self.q_table or provider_id not in self.q_table[state_key]:
            return

        current_q = self.q_table[state_key][provider_id]

        # If terminal state or no next state, maximal future Q is 0
        max_future_q = 0.0
        if next_state_key and next_state_key in self.q_table:
            max_future_q = max(self.q_table[next_state_key].values())

        # Bellman update
        new_q = current_q + self.alpha * (reward + self.gamma * max_future_q - current_q)
        self.q_table[state_key][provider_id] = new_q

        self.reward_history.append(reward)

    def decay_epsilon(self):
        """Decay exploration rate over time."""
        self.epsilon = max(self.epsilon_min, self.epsilon * self.epsilon_decay)

    def get_stats(self) -> Dict:
        """Get current agent statistics."""
        avg_reward = sum(self.reward_history[-100:]) / max(len(self.reward_history[-100:]), 1)

        return {
            "epsilon": self.epsilon,
            "decision_count": self.decision_count,
            "q_states": len(self.q_table),
            "avg_reward_100": avg_reward,
            "total_rewards": len(self.reward_history),
        }

    def save(self, path: str):
        """Save Q-table and parameters to file."""
        state = {
            "q_table": self.q_table,
            "epsilon": self.epsilon,
            "decision_count": self.decision_count,
            "reward_history": self.reward_history[-1000:],  # Keep last 1000
        }
        with open(path, 'w') as f:
            json.dump(state, f, indent=2)

    def load(self, path: str):
        """Load Q-table and parameters from file."""
        with open(path, 'r') as f:
            state = json.load(f)

        self.q_table = state["q_table"]
        self.epsilon = state["epsilon"]
        self.decision_count = state["decision_count"]
        self.reward_history = state["reward_history"]
