"""
AI Agent for Multi-Provider Routing
Uses Q-learning to optimize routing decisions
"""

import numpy as np
import json
from typing import Dict, List, Tuple
from dataclasses import dataclass

@dataclass
class State:
    """Environment state observed by agent"""
    provider_latencies: np.ndarray
    provider_prices: np.ndarray
    provider_capacities: np.ndarray
    provider_reputations: np.ndarray
    current_fill_rate: float
    current_cost: float
    step: int

class RoutingAgent:
    """Q-learning agent for provider selection"""
    
    def __init__(self, n_providers: int, learning_rate: float = 0.1, 
                 discount: float = 0.95, epsilon: float = 0.1):
        self.n_providers = n_providers
        self.lr = learning_rate
        self.gamma = discount
        self.epsilon = epsilon
        self.q_table: Dict[int, np.ndarray] = {}
        self.memory: List[Tuple] = []
        self.memory_size = 10000
        
    def _hash_state(self, state: State) -> int:
        """Discretize continuous state into hash"""
        lat_bins = np.digitize(state.provider_latencies, bins=[100, 200, 300, 400, 500])
        price_bins = np.digitize(state.provider_prices, bins=[1.0, 2.0, 3.0, 5.0, 10.0])
        cap_bins = np.digitize(state.provider_capacities, bins=[50, 100, 150, 200])
        state_tuple = tuple(lat_bins) + tuple(price_bins) + tuple(cap_bins)
        return hash(state_tuple)
    
    def get_q_values(self, state: State) -> np.ndarray:
        """Get Q-values for all actions in state"""
        state_hash = self._hash_state(state)
        if state_hash not in self.q_table:
            self.q_table[state_hash] = np.zeros(self.n_providers)
        return self.q_table[state_hash]
    
    def select_action(self, state: State, explore: bool = True) -> int:
        """Epsilon-greedy action selection"""
        if explore and np.random.random() < self.epsilon:
            return np.random.randint(self.n_providers)
        else:
            q_values = self.get_q_values(state)
            return int(np.argmax(q_values))
    
    def update(self, state: State, action: int, reward: float, next_state: State):
        """Q-learning update"""
        state_hash = self._hash_state(state)
        next_state_hash = self._hash_state(next_state)
        
        if state_hash not in self.q_table:
            self.q_table[state_hash] = np.zeros(self.n_providers)
        if next_state_hash not in self.q_table:
            self.q_table[next_state_hash] = np.zeros(self.n_providers)
        
        current_q = self.q_table[state_hash][action]
        max_next_q = np.max(self.q_table[next_state_hash])
        new_q = current_q + self.lr * (reward + self.gamma * max_next_q - current_q)
        self.q_table[state_hash][action] = new_q
        
        self.memory.append((state, action, reward, next_state))
        if len(self.memory) > self.memory_size:
            self.memory.pop(0)
    
    def save(self, path: str):
        """Save Q-table to disk"""
        data = {
            'q_table': {str(k): v.tolist() for k, v in self.q_table.items()},
            'n_providers': self.n_providers
        }
        with open(path, 'w') as f:
            json.dump(data, f)


def compute_reward(fill_rate: float, avg_cost: float, avg_latency: float) -> float:
    """Reward function balancing multiple objectives"""
    fill_reward = fill_rate * 100
    cost_penalty = avg_cost * 10
    latency_penalty = avg_latency / 10
    
    return fill_reward * 0.5 - cost_penalty * 0.3 - latency_penalty * 0.2
