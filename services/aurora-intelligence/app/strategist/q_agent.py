"""
Q-Learning Agent - Ported from sim/ai-mesh/agent.py
Adapted for production use with decision tracing
"""

import random
from collections import defaultdict
from typing import Dict, List, Any, Tuple
import json


class QAgent:
    """
    Q-learning agent for multi-provider routing decisions

    Uses epsilon-greedy exploration and tabular Q-learning to learn
    optimal provider selection policies from feedback.
    """

    def __init__(
        self,
        actions: List[str],
        alpha: float = 0.2,
        gamma: float = 0.92,
        epsilon: float = 0.1
    ):
        """
        Initialize Q-learning agent

        Args:
            actions: List of possible action identifiers (e.g., candidate indices)
            alpha: Learning rate (0-1)
            gamma: Discount factor for future rewards (0-1)
            epsilon: Exploration rate (0-1)
        """
        self.Q: Dict[str, Dict[str, float]] = defaultdict(lambda: defaultdict(float))
        self.alpha = alpha
        self.gamma = gamma
        self.epsilon = epsilon
        self.actions = actions
        self.episodes = 0
        self.updates = 0

    def act(self, state_key: str, explore: bool = True) -> str:
        """
        Select action using epsilon-greedy policy

        Args:
            state_key: Discretized state representation
            explore: Whether to use epsilon-greedy (True) or pure exploitation (False)

        Returns:
            Selected action identifier
        """
        # Epsilon-greedy exploration
        if explore and random.random() < self.epsilon:
            return random.choice(self.actions)

        # Exploitation: choose action with highest Q-value
        q_row = self.Q[state_key]
        if not q_row:
            # No Q-values yet, random choice
            return random.choice(self.actions)

        return max(self.actions, key=lambda a: q_row.get(a, 0.0))

    def get_q_value(self, state_key: str, action: str) -> float:
        """Get Q-value for state-action pair"""
        return self.Q[state_key].get(action, 0.0)

    def get_best_q(self, state_key: str) -> Tuple[str, float]:
        """
        Get best action and Q-value for state

        Returns:
            Tuple of (best_action, best_q_value)
        """
        q_row = self.Q[state_key]
        if not q_row:
            return self.actions[0], 0.0

        best_action = max(self.actions, key=lambda a: q_row.get(a, 0.0))
        best_q = q_row.get(best_action, 0.0)
        return best_action, best_q

    def update(
        self,
        state: str,
        action: str,
        reward: float,
        next_state: str
    ) -> float:
        """
        Q-learning update rule

        Q(s,a) ← Q(s,a) + α[r + γ max_a' Q(s',a') - Q(s,a)]

        Args:
            state: Current state key
            action: Action taken
            reward: Observed reward
            next_state: Next state key

        Returns:
            Updated Q-value
        """
        current_q = self.Q[state][action]

        # Get max Q-value for next state
        next_q_row = self.Q[next_state]
        max_next_q = max(next_q_row.values()) if next_q_row else 0.0

        # Bellman update
        new_q = current_q + self.alpha * (reward + self.gamma * max_next_q - current_q)
        self.Q[state][action] = new_q

        self.updates += 1
        return new_q

    def decay_epsilon(self, decay_rate: float = 0.995, min_epsilon: float = 0.01):
        """Decay exploration rate over time"""
        self.epsilon = max(min_epsilon, self.epsilon * decay_rate)

    def get_stats(self) -> Dict[str, Any]:
        """Get agent statistics"""
        return {
            "episodes": self.episodes,
            "updates": self.updates,
            "epsilon": self.epsilon,
            "alpha": self.alpha,
            "gamma": self.gamma,
            "q_table_size": len(self.Q),
            "total_state_action_pairs": sum(len(row) for row in self.Q.values()),
        }

    def save_checkpoint(self, path: str):
        """Save Q-table to JSON"""
        checkpoint = {
            "Q": {k: dict(v) for k, v in self.Q.items()},
            "hyperparameters": {
                "alpha": self.alpha,
                "gamma": self.gamma,
                "epsilon": self.epsilon,
            },
            "stats": self.get_stats(),
        }
        with open(path, 'w') as f:
            json.dump(checkpoint, f, indent=2)

    def load_checkpoint(self, path: str):
        """Load Q-table from JSON"""
        with open(path, 'r') as f:
            checkpoint = json.load(f)

        # Restore Q-table
        self.Q = defaultdict(
            lambda: defaultdict(float),
            {k: defaultdict(float, v) for k, v in checkpoint["Q"].items()}
        )

        # Restore hyperparameters
        hp = checkpoint.get("hyperparameters", {})
        self.epsilon = hp.get("epsilon", self.epsilon)

        # Restore stats
        stats = checkpoint.get("stats", {})
        self.episodes = stats.get("episodes", 0)
        self.updates = stats.get("updates", 0)
