#!/usr/bin/env python3
"""
Integration layer: AI Mesh → Ψ-Field → Remembrancer
Connects RL agents with consciousness tracking and cryptographic memory
"""

import requests
import json
import subprocess
from typing import Dict, List
from datetime import datetime

class PsiFieldIntegration:
    """Bridge between AI agents and Ψ-Field service"""
    
    def __init__(self, psi_url: str = "http://localhost:8000", 
                 remembrancer_path: str = "./ops/bin/remembrancer"):
        self.psi_url = psi_url
        self.remembrancer = remembrancer_path
        self.session_id = datetime.utcnow().strftime("%Y%m%d-%H%M%S")
        
    def send_agent_metrics(self, agent_rewards: List[float]) -> Dict:
        """
        Send agent performance to Ψ-Field for consciousness tracking
        
        Args:
            agent_rewards: List of rewards from each agent in swarm
            
        Returns:
            Ψ-Field metrics (Ψ, C, U, Φ, H, PE)
        """
        # Pad or truncate to 16 dimensions (Ψ-Field input)
        x = agent_rewards[:16] if len(agent_rewards) >= 16 else \
            agent_rewards + [0.0] * (16 - len(agent_rewards))
        
        try:
            response = requests.post(
                f"{self.psi_url}/step",
                json={"x": x, "apply_guardian": True},
                timeout=5
            )
            
            if response.ok:
                return response.json()
            else:
                print(f"Ψ-Field error: {response.status_code}")
                return {}
                
        except Exception as e:
            print(f"Ψ-Field connection failed: {e}")
            return {}
    
    def record_training_step(self, episode: int, metrics: Dict):
        """
        Record training step to Remembrancer
        
        Args:
            episode: Episode number
            metrics: Training metrics (rewards, Ψ metrics, etc.)
        """
        try:
            # Create evidence file
            evidence_path = f"/tmp/ai-mesh-{self.session_id}-ep{episode}.json"
            with open(evidence_path, 'w') as f:
                json.dump(metrics, f, indent=2)
            
            # Record to Remembrancer
            subprocess.run([
                self.remembrancer, "record", "deploy",
                "--component", "ai-mesh-training",
                "--version", f"ep{episode}",
                "--evidence", evidence_path
            ], check=True, capture_output=True)
            
        except Exception as e:
            print(f"Remembrancer recording failed: {e}")
    
    def check_intervention_needed(self, psi_metrics: Dict) -> str:
        """
        Check if Guardian intervention is needed based on Ψ metrics
        
        Returns:
            'nigredo', 'albedo', or None
        """
        pe = psi_metrics.get('PE', 0)
        h = psi_metrics.get('H', 0)
        psi = psi_metrics.get('Psi', 0)
        
        # Critical prediction error
        if pe > 1.5:
            return 'nigredo'
        
        # High entropy with low consciousness
        if h > 2.0 and psi < 0.3:
            return 'albedo'
        
        # Check Guardian recommendation
        guardian = psi_metrics.get('_guardian', {})
        if guardian.get('intervention'):
            return guardian['intervention']
        
        return None
    
    def get_swarm_health(self) -> Dict:
        """Get current Ψ-Field state for swarm health check"""
        try:
            response = requests.get(f"{self.psi_url}/state", timeout=5)
            if response.ok:
                return response.json()
        except:
            pass
        return {}


def example_training_loop():
    """Example: Integrate AI mesh training with Ψ-Field"""
    
    integration = PsiFieldIntegration()
    
    # Simulate training
    for episode in range(10):
        # Simulate agent rewards
        agent_rewards = [40.0 + i * 0.5 for i in range(10)]
        
        # Send to Ψ-Field
        psi_metrics = integration.send_agent_metrics(agent_rewards)
        print(f"Episode {episode}: Ψ={psi_metrics.get('Psi', 0):.3f}, "
              f"PE={psi_metrics.get('PE', 0):.3f}")
        
        # Check for intervention
        intervention = integration.check_intervention_needed(psi_metrics)
        if intervention:
            print(f"  → Guardian intervention: {intervention}")
        
        # Record to Remembrancer
        metrics = {
            'episode': episode,
            'agent_rewards': agent_rewards,
            'psi_metrics': psi_metrics,
            'intervention': intervention
        }
        integration.record_training_step(episode, metrics)
    
    print("\nTraining complete. All steps recorded to Remembrancer.")


if __name__ == '__main__':
    example_training_loop()
