"""
AI Swarm Coordinator with Ψ-Field Integration
Multiple agents coordinate via consciousness metrics
"""

import numpy as np
import requests
from typing import List, Dict
from agent import RoutingAgent, State, compute_reward

class SwarmCoordinator:
    """Coordinates multiple AI agents via Ψ-Field"""
    
    def __init__(self, n_agents: int, n_providers: int, psi_field_url: str = "http://localhost:8000"):
        self.n_agents = n_agents
        self.agents = [RoutingAgent(n_providers) for _ in range(n_agents)]
        self.psi_url = psi_field_url
        self.agent_metrics = []
        
    def step(self, states: List[State]) -> List[int]:
        """All agents select actions simultaneously"""
        actions = []
        for i, state in enumerate(states):
            action = self.agents[i].select_action(state)
            actions.append(action)
        return actions
    
    def update_swarm(self, states: List[State], actions: List[int], 
                     rewards: List[float], next_states: List[State]):
        """Update all agents and compute swarm consciousness"""
        
        # Update individual agents
        for i in range(self.n_agents):
            self.agents[i].update(states[i], actions[i], rewards[i], next_states[i])
        
        # Compute swarm metrics for Ψ-Field
        agent_performances = np.array(rewards)
        swarm_input = np.concatenate([
            agent_performances[:8] if len(agent_performances) >= 8 else 
            np.pad(agent_performances, (0, 8 - len(agent_performances)))
        ])
        
        # Send to Ψ-Field
        try:
            response = requests.post(f"{self.psi_url}/step", json={
                "x": swarm_input.tolist(),
                "apply_guardian": True
            }, timeout=5)
            
            if response.ok:
                psi_metrics = response.json()
                self.agent_metrics.append(psi_metrics)
                
                # Check for intervention needed
                if psi_metrics.get('PE', 0) > 0.7:
                    self._apply_intervention(psi_metrics)
                    
        except Exception as e:
            print(f"Ψ-Field connection failed: {e}")
    
    def _apply_intervention(self, psi_metrics: Dict):
        """Apply Guardian intervention to swarm"""
        intervention = psi_metrics.get('_guardian', {}).get('intervention')
        
        if intervention == 'nigredo':
            # Reset worst-performing agents
            performances = [len(agent.q_table) for agent in self.agents]
            worst_idx = np.argmin(performances)
            self.agents[worst_idx] = RoutingAgent(self.agents[worst_idx].n_providers)
            print(f"Nigredo: Reset agent {worst_idx}")
            
        elif intervention == 'albedo':
            # Increase exploration for all agents
            for agent in self.agents:
                agent.epsilon = min(0.3, agent.epsilon * 1.5)
            print(f"Albedo: Increased exploration")
    
    def get_swarm_consciousness(self) -> Dict:
        """Get aggregate swarm metrics"""
        if not self.agent_metrics:
            return {}
        
        latest = self.agent_metrics[-1]
        return {
            'psi': latest.get('Psi', 0),
            'coherence': latest.get('C', 0),
            'prediction_error': latest.get('PE', 0),
            'n_agents': self.n_agents,
            'total_states_explored': sum(len(a.q_table) for a in self.agents)
        }
    
    def save_swarm(self, prefix: str):
        """Save all agents"""
        for i, agent in enumerate(self.agents):
            agent.save(f"{prefix}_agent_{i}.json")
