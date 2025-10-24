#!/usr/bin/env python3
"""
Train AI agent swarm on multi-provider routing
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../multi-provider-routing-simulator'))

import argparse
import numpy as np
from swarm import SwarmCoordinator
from agent import State, compute_reward
from sim.sim import Router, ProviderState, ScenarioEngine, Request
import json

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--agents', type=int, default=10)
    parser.add_argument('--episodes', type=int, default=1000)
    parser.add_argument('--steps-per-episode', type=int, default=100)
    parser.add_argument('--learning-rate', type=float, default=0.1)
    parser.add_argument('--epsilon', type=float, default=0.1)
    parser.add_argument('--psi-field', type=str, default='http://localhost:8000')
    parser.add_argument('--output', type=str, default='out')
    args = parser.parse_args()
    
    os.makedirs(args.output, exist_ok=True)
    
    # Load provider configs
    config_dir = os.path.join(os.path.dirname(__file__), '../multi-provider-routing-simulator/config')
    with open(os.path.join(config_dir, 'providers.json')) as f:
        providers_cfg = json.load(f)
    
    n_providers = len(providers_cfg['providers'])
    
    # Initialize swarm
    print(f"Initializing swarm: {args.agents} agents, {n_providers} providers")
    swarm = SwarmCoordinator(args.agents, n_providers, args.psi_field)
    
    # Training loop
    training_metrics = []
    
    for episode in range(args.episodes):
        episode_rewards = []
        
        for step in range(args.steps_per_episode):
            # Create states for each agent (simplified)
            states = []
            for _ in range(args.agents):
                state = State(
                    provider_latencies=np.random.uniform(250, 450, n_providers),
                    provider_prices=np.random.uniform(1.0, 3.0, n_providers),
                    provider_capacities=np.random.uniform(100, 250, n_providers),
                    provider_reputations=np.random.uniform(60, 90, n_providers),
                    current_fill_rate=0.95,
                    current_cost=2.5,
                    step=step
                )
                states.append(state)
            
            # Agents select actions
            actions = swarm.step(states)
            
            # Simulate outcomes (simplified)
            rewards = []
            next_states = []
            for i, action in enumerate(actions):
                # Simulate routing outcome
                fill_rate = np.random.uniform(0.90, 1.0)
                avg_cost = np.random.uniform(2.0, 3.0)
                avg_latency = np.random.uniform(280, 350)
                
                reward = compute_reward(fill_rate, avg_cost, avg_latency)
                rewards.append(reward)
                episode_rewards.append(reward)
                
                # Next state (simplified)
                next_states.append(states[i])
            
            # Update swarm
            swarm.update_swarm(states, actions, rewards, next_states)
        
        # Episode metrics
        avg_reward = np.mean(episode_rewards)
        swarm_consciousness = swarm.get_swarm_consciousness()
        
        training_metrics.append({
            'episode': episode,
            'avg_reward': avg_reward,
            'psi': swarm_consciousness.get('psi', 0),
            'coherence': swarm_consciousness.get('coherence', 0),
            'prediction_error': swarm_consciousness.get('prediction_error', 0),
            'states_explored': swarm_consciousness.get('total_states_explored', 0)
        })
        
        if episode % 100 == 0:
            print(f"Episode {episode}: avg_reward={avg_reward:.2f}, "
                  f"psi={swarm_consciousness.get('psi', 0):.3f}, "
                  f"states={swarm_consciousness.get('total_states_explored', 0)}")
    
    # Save results
    swarm.save_swarm(os.path.join(args.output, 'swarm_final'))
    
    with open(os.path.join(args.output, 'training_metrics.json'), 'w') as f:
        json.dump(training_metrics, f, indent=2)
    
    print(f"\nTraining complete. Results saved to {args.output}/")
    print(f"Final swarm consciousness: {swarm.get_swarm_consciousness()}")

if __name__ == '__main__':
    main()
