"""
VaultMesh Ψ-Field Federation Module
-----------------------------------
Implements the multi-agent swarm coherence for the Ψ-Field Evolution Algorithm
"""

import os
import sys
import json
import time
import logging
import asyncio
import numpy as np
import httpx
from typing import Dict, List, Any, Optional, Tuple

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("psi-field-federation")

class PsiFederation:
    """Federation handler for Ψ-Field to integrate with Aurora Layer 3"""
    
    def __init__(self, config_path=None):
        self.peers = []
        self.agent_id = f"psi-field-{os.getenv('HOSTNAME', 'local')}"
        self.federation_enabled = False
        self.load_config(config_path)
        
        self.metrics = {
            "C_swarm": 0.0,
            "Phi_swarm": 0.0,
            "U_swarm": 0.0,
            "H_swarm": 0.0,
            "Psi_swarm": 0.0,
        }
        
        # Weights for swarm Ψ calculation
        self.weights = {
            "v1": 0.7,  # C_swarm
            "v2": 0.6,  # Phi_swarm
            "v3": 0.5,  # U_swarm
            "v4": 0.4,  # H_swarm
        }
    
    def load_config(self, config_path=None):
        """Load federation configuration from file or environment variables"""
        if not config_path:
            config_path = os.getenv(
                "FEDERATION_CONFIG", 
                os.path.join(os.path.dirname(__file__), '..', '..', 'services/federation/config/peers.yaml')
            )
        
        try:
            import yaml
            with open(config_path, 'r') as f:
                self.config = yaml.safe_load(f)
                self.peers = self.config.get('peers', [])
                self.federation_enabled = True
                logger.info(f"Loaded federation config with {len(self.peers)} peers")
        except Exception as e:
            logger.warning(f"Failed to load federation config: {e}")
            # Try to get peers from environment variable
            peers_env = os.getenv("FEDERATION_PEERS")
            if peers_env:
                self.peers = peers_env.split(",")
                self.federation_enabled = True
                logger.info(f"Loaded federation peers from environment: {len(self.peers)} peers")
    
    async def publish_metrics(self, metrics: Dict[str, float], psi: float, phase: complex = None):
        """Publish agent metrics to the mesh"""
        if not self.federation_enabled or not self.peers:
            return
            
        # Prepare data to publish
        data = {
            "agent_id": self.agent_id,
            "psi": psi,
            "metrics": metrics,
            "timestamp": time.time()
        }
        
        # Include phase information if available
        if phase is not None:
            data["phase"] = {
                "real": float(phase.real),
                "imag": float(phase.imag)
            }
        
        # Send to all peers
        tasks = []
        for peer in self.peers:
            try:
                url = f"{peer}/federation/metrics"
                async with httpx.AsyncClient() as client:
                    tasks.append(client.post(url, json=data, timeout=2.0))
            except Exception as e:
                logger.error(f"Failed to publish to peer {peer}: {e}")
                
        if tasks:
            results = await asyncio.gather(*tasks, return_exceptions=True)
            success_count = sum(1 for r in results if not isinstance(r, Exception))
            logger.info(f"Published metrics to {success_count}/{len(tasks)} peers")
    
    async def get_swarm_metrics(self) -> Dict[str, float]:
        """Retrieve and calculate swarm-level metrics"""
        if not self.federation_enabled or not self.peers:
            return self.metrics
            
        all_metrics = []
        phases = []
        
        # Fetch metrics from all peers
        for peer in self.peers:
            try:
                url = f"{peer}/federation/metrics"
                async with httpx.AsyncClient() as client:
                    response = await client.get(url, timeout=2.0)
                    if response.status_code == 200:
                        metrics = response.json()
                        all_metrics.append(metrics)
                        
                        # Extract phase information for Phi_swarm calculation
                        if "phase" in metrics:
                            phase = metrics["phase"]
                            phases.append(complex(phase["real"], phase["imag"]))
                            
            except Exception as e:
                logger.error(f"Failed to get metrics from peer {peer}: {e}")
        
        # Calculate swarm-level metrics if we got any
        if all_metrics:
            C_values = [m.get("metrics", {}).get("C", 0) for m in all_metrics]
            U_values = [m.get("metrics", {}).get("U", 0) for m in all_metrics]
            H_values = [m.get("metrics", {}).get("H", 0) for m in all_metrics]
            
            # Update swarm metrics
            self.metrics["C_swarm"] = float(np.mean(C_values))
            self.metrics["U_swarm"] = float(np.mean(U_values))
            self.metrics["H_swarm"] = float(np.mean(H_values))
            
            # Calculate Phi_swarm
            if phases:
                self.metrics["Phi_swarm"] = float(abs(np.mean(phases)))
            
            # Calculate Psi_swarm
            w = self.weights
            self.metrics["Psi_swarm"] = float(self._sigmoid(
                w["v1"] * self.metrics["C_swarm"] +
                w["v2"] * self.metrics["Phi_swarm"] +
                w["v3"] * self.metrics["U_swarm"] -
                w["v4"] * self.metrics["H_swarm"]
            ))
            
            logger.info(f"Calculated swarm metrics: Psi_swarm={self.metrics['Psi_swarm']:.4f}")
            
        return self.metrics
    
    def _sigmoid(self, x):
        """Squashing function"""
        return 1.0 / (1.0 + np.exp(-x))
    
    async def register_with_aurora(self):
        """Register this agent with the Aurora mesh"""
        if not self.federation_enabled or not self.peers:
            return
            
        # Registration data
        data = {
            "agent_id": self.agent_id,
            "service_type": "psi-field",
            "capabilities": ["psi-evolution", "retention", "protention"],
            "api_version": "v1.0",
            "timestamp": time.time()
        }
        
        # Register with all peers
        tasks = []
        for peer in self.peers:
            try:
                url = f"{peer}/federation/register"
                async with httpx.AsyncClient() as client:
                    tasks.append(client.post(url, json=data, timeout=5.0))
            except Exception as e:
                logger.error(f"Failed to register with peer {peer}: {e}")
                
        if tasks:
            results = await asyncio.gather(*tasks, return_exceptions=True)
            success_count = sum(1 for r in results if not isinstance(r, Exception))
            logger.info(f"Registered with {success_count}/{len(tasks)} Aurora peers")
    
    async def startup(self):
        """Startup tasks for federation"""
        logger.info(f"Federation startup for agent {self.agent_id}")
        if self.federation_enabled and self.peers:
            await self.register_with_aurora()
        else:
            logger.info("Federation disabled or no peers configured")
    
    async def shutdown(self):
        """Shutdown tasks for federation"""
        logger.info(f"Federation shutdown for agent {self.agent_id}")
        # Add any cleanup tasks here if needed

# Federation instance for use in the main API
federation = PsiFederation()