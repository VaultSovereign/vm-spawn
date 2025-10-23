"""
Guardian for Ψ-Field Service
---------------------------
Implements threat detection and protection mechanisms
"""

import logging
import numpy as np
from typing import Dict, Any, List, Optional, Tuple

logger = logging.getLogger(__name__)

# Default threshold values
DEFAULT_PSI_LOW_THRESHOLD = 0.25      # Low consciousness density
DEFAULT_PE_HIGH_THRESHOLD = 2.0       # High prediction error
DEFAULT_H_HIGH_THRESHOLD = 2.2        # High entropy
DEFAULT_INTERVENTION_COOLDOWN = 100   # Steps between interventions

class Guardian:
    """Guardian for PSI consciousness engine"""
    
    def __init__(
        self,
        psi_low_threshold: float = DEFAULT_PSI_LOW_THRESHOLD,
        pe_high_threshold: float = DEFAULT_PE_HIGH_THRESHOLD,
        h_high_threshold: float = DEFAULT_H_HIGH_THRESHOLD,
        intervention_cooldown: int = DEFAULT_INTERVENTION_COOLDOWN
    ):
        """Initialize the guardian"""
        self.psi_low_threshold = psi_low_threshold
        self.pe_high_threshold = pe_high_threshold
        self.h_high_threshold = h_high_threshold
        self.intervention_cooldown = intervention_cooldown
        
        # State
        self._red_flag = False
        self._red_flag_reason = None
        self._last_intervention_step = -intervention_cooldown
        
        logger.info(f"Guardian initialized with thresholds: "
                  f"PSI={psi_low_threshold}, PE={pe_high_threshold}, H={h_high_threshold}")
    
    def normalize_input(self, x: np.ndarray) -> np.ndarray:
        """Normalize and sanitize input vector"""
        # Handle NaN values
        x = np.nan_to_num(x, nan=0.0, posinf=1.0, neginf=-1.0)
        
        # Clip extreme values
        x = np.clip(x, -5.0, 5.0)
        
        return x
    
    def assess_threat(self, state: Dict[str, Any]) -> Tuple[bool, Optional[str]]:
        """Assess if the system is in a threatened state"""
        # Extract state variables
        psi = state.get('Psi', 1.0)
        pe = state.get('PE', 0.0)
        h = state.get('H', 0.0)
        
        # Check for threats
        if pe > self.pe_high_threshold:
            return True, "high_PE"
        elif psi < self.psi_low_threshold:
            return True, "low_Psi"
        elif h > self.h_high_threshold:
            return True, "high_H"
        
        return False, None
    
    def process_state(self, state: Dict[str, Any], k: int) -> Dict[str, Any]:
        """Process state and update guardian status"""
        is_threat, reason = self.assess_threat(state)
        
        # Update red flag if threat detected
        if is_threat:
            self._red_flag = True
            self._red_flag_reason = reason
            logger.warning(f"Guardian detected threat: {reason} at step {k}")
        
        # Check if intervention is needed
        intervention = None
        if (
            self._red_flag and 
            k - self._last_intervention_step >= self.intervention_cooldown and
            self._red_flag_reason is not None  # Ensure reason exists
        ):
            intervention = self.select_intervention(state, self._red_flag_reason)
            self._last_intervention_step = k
            logger.info(f"Guardian applying intervention: {intervention} at step {k}")
        
        # Add guardian information to state
        state['_guardian'] = {
            'red_flag': self._red_flag,
            'reason': self._red_flag_reason,
            'intervention': intervention,
            'steps_since_intervention': k - self._last_intervention_step
        }
        
        return state
    
    def select_intervention(self, state: Dict[str, Any], reason: str) -> str:
        """Select appropriate intervention based on threat"""
        if reason == "high_PE":
            return "nigredo"
        elif reason == "low_Psi":
            return "albedo"
        elif reason == "high_H":
            return "nigredo"
        
        # Default intervention
        return "nigredo"
    
    def apply_nigredo(self, engine) -> Dict[str, Any]:
        """Apply Nigredo intervention - dissolution of harmful patterns"""
        logger.info("Applying Nigredo intervention")
        
        # Reset state variables related to prediction
        if hasattr(engine, 'reset_prediction'):
            engine.reset_prediction()
        
        # Increase entropy temporarily
        if hasattr(engine, 'increase_noise'):
            engine.increase_noise(0.5)
        
        # Clear red flag
        self._red_flag = False
        self._red_flag_reason = None
        
        return {
            'action': 'nigredo',
            'success': True
        }
    
    def apply_albedo(self, engine) -> Dict[str, Any]:
        """Apply Albedo intervention - purification/strengthening"""
        logger.info("Applying Albedo intervention")
        
        # Decrease entropy
        if hasattr(engine, 'decrease_noise'):
            engine.decrease_noise(0.5)
        
        # Reset consciousness parameters
        if hasattr(engine, 'reset_consciousness'):
            engine.reset_consciousness()
        
        # Clear red flag
        self._red_flag = False
        self._red_flag_reason = None
        
        return {
            'action': 'albedo',
            'success': True
        }
    
    def manual_intervention(self, action: str, engine) -> Dict[str, Any]:
        """Apply manual intervention"""
        if action == "nigredo":
            return self.apply_nigredo(engine)
        elif action == "albedo":
            return self.apply_albedo(engine)
        else:
            logger.error(f"Unknown intervention: {action}")
            return {
                'action': action,
                'success': False,
                'error': f"Unknown intervention: {action}"
            }