"""
Advanced Guardian with Percentile-Based Thresholds
-------------------------------------------------
Adaptive threat detection using rolling statistics
"""

import logging
import numpy as np
from typing import Dict, Any, List, Optional, Tuple, Deque
from collections import deque

logger = logging.getLogger(__name__)

class AdvancedGuardian:
    """
    Guardian with percentile-based adaptive thresholds.
    Tracks rolling history and uses p95/p99 for anomaly detection.
    """
    
    def __init__(
        self,
        history_window: int = 200,
        percentile_threshold: float = 95.0,
        intervention_cooldown: int = 100,
        min_samples: int = 50
    ):
        """
        Initialize Advanced Guardian
        
        Args:
            history_window: Number of recent steps to track
            percentile_threshold: Percentile for anomaly detection (95 or 99)
            intervention_cooldown: Minimum steps between interventions
            min_samples: Minimum samples before using percentiles
        """
        self.history_window = history_window
        self.percentile_threshold = percentile_threshold
        self.intervention_cooldown = intervention_cooldown
        self.min_samples = min_samples
        
        # Rolling history buffers
        self.pe_history: Deque[float] = deque(maxlen=history_window)
        self.h_history: Deque[float] = deque(maxlen=history_window)
        self.psi_history: Deque[float] = deque(maxlen=history_window)
        
        # Fallback static thresholds (used until enough samples)
        self.static_psi_low = 0.25
        self.static_pe_high = 2.0
        self.static_h_high = 2.2
        
        # State
        self._red_flag = False
        self._red_flag_reason = None
        self._last_intervention_step = -intervention_cooldown
        self._intervention_count = 0
        
        logger.info(f"AdvancedGuardian initialized: p{percentile_threshold}, "
                   f"window={history_window}, cooldown={intervention_cooldown}")
    
    def normalize_input(self, x: np.ndarray) -> np.ndarray:
        """Normalize and sanitize input vector"""
        x = np.nan_to_num(x, nan=0.0, posinf=1.0, neginf=-1.0)
        x = np.clip(x, -5.0, 5.0)
        return x
    
    def _compute_thresholds(self) -> Tuple[float, float, float]:
        """
        Compute adaptive thresholds based on history
        
        Returns:
            (psi_low_threshold, pe_high_threshold, h_high_threshold)
        """
        # Use static thresholds if not enough samples
        if len(self.psi_history) < self.min_samples:
            return (
                self.static_psi_low,
                self.static_pe_high,
                self.static_h_high
            )
        
        # Compute percentiles
        psi_low = np.percentile(list(self.psi_history), 100 - self.percentile_threshold)
        pe_high = np.percentile(list(self.pe_history), self.percentile_threshold)
        h_high = np.percentile(list(self.h_history), self.percentile_threshold)
        
        return (psi_low, pe_high, h_high)
    
    def assess_threat(self, state: Dict[str, Any]) -> Tuple[bool, Optional[str]]:
        """
        Assess if the system is in a threatened state using adaptive thresholds
        
        Args:
            state: Current state dictionary
        
        Returns:
            (is_threat, reason)
        """
        # Extract metrics
        psi = state.get('Psi', 1.0)
        pe = state.get('PE', 0.0)
        h = state.get('H', 0.0)
        
        # Update history
        self.psi_history.append(psi)
        self.pe_history.append(pe)
        self.h_history.append(h)
        
        # Get current thresholds
        psi_low, pe_high, h_high = self._compute_thresholds()
        
        # Check for threats
        if pe > pe_high:
            return True, f"high_PE:{pe:.3f}>p{self.percentile_threshold}:{pe_high:.3f}"
        elif psi < psi_low:
            return True, f"low_Psi:{psi:.3f}<p{100-self.percentile_threshold}:{psi_low:.3f}"
        elif h > h_high:
            return True, f"high_H:{h:.3f}>p{self.percentile_threshold}:{h_high:.3f}"
        
        return False, None
    
    def process_state(self, state: Dict[str, Any], k: int) -> Dict[str, Any]:
        """
        Process state and update guardian status
        
        Args:
            state: Current state
            k: Step counter
        
        Returns:
            state: Updated state with guardian info
        """
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
            self._red_flag_reason is not None
        ):
            intervention = self.select_intervention(state, self._red_flag_reason)
            self._last_intervention_step = k
            self._intervention_count += 1
            logger.info(f"Guardian applying intervention: {intervention} at step {k} "
                       f"(total: {self._intervention_count})")
        
        # Get current thresholds for transparency
        psi_low, pe_high, h_high = self._compute_thresholds()
        
        # Add guardian information to state
        state['_guardian'] = {
            'red_flag': self._red_flag,
            'reason': self._red_flag_reason,
            'intervention': intervention,
            'steps_since_intervention': k - self._last_intervention_step,
            'intervention_count': self._intervention_count,
            'thresholds': {
                'psi_low': float(psi_low),
                'pe_high': float(pe_high),
                'h_high': float(h_high),
                'type': 'adaptive' if len(self.psi_history) >= self.min_samples else 'static'
            },
            'history_size': len(self.psi_history)
        }
        
        return state
    
    def select_intervention(self, state: Dict[str, Any], reason: str) -> str:
        """Select appropriate intervention based on threat"""
        # Parse reason to get the metric
        if "high_PE" in reason or "high_H" in reason:
            return "nigredo"
        elif "low_Psi" in reason:
            return "albedo"
        
        # Default intervention
        return "nigredo"
    
    def apply_nigredo(self, engine) -> Dict[str, Any]:
        """Apply Nigredo intervention"""
        logger.info("Applying Nigredo intervention (dissolution)")
        
        # Call backend-specific methods if available
        if hasattr(engine, 'increase_noise'):
            engine.increase_noise(1.5)
        if hasattr(engine, 'reset_state'):
            engine.reset_state()
        
        # Clear red flag
        self._red_flag = False
        self._red_flag_reason = None
        
        return {
            'action': 'nigredo',
            'success': True,
            'timestamp': np.datetime64('now').astype(str)
        }
    
    def apply_albedo(self, engine) -> Dict[str, Any]:
        """Apply Albedo intervention"""
        logger.info("Applying Albedo intervention (purification)")
        
        # Call backend-specific methods if available
        if hasattr(engine, 'decrease_noise'):
            engine.decrease_noise(0.7)
        
        # Clear red flag
        self._red_flag = False
        self._red_flag_reason = None
        
        return {
            'action': 'albedo',
            'success': True,
            'timestamp': np.datetime64('now').astype(str)
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
    
    def get_statistics(self) -> Dict[str, Any]:
        """Get guardian statistics"""
        if len(self.psi_history) < 2:
            return {'message': 'Not enough history'}
        
        psi_low, pe_high, h_high = self._compute_thresholds()
        
        return {
            'history_size': len(self.psi_history),
            'thresholds': {
                'psi_low': float(psi_low),
                'pe_high': float(pe_high),
                'h_high': float(h_high),
                'type': 'adaptive' if len(self.psi_history) >= self.min_samples else 'static'
            },
            'statistics': {
                'psi': {
                    'mean': float(np.mean(list(self.psi_history))),
                    'std': float(np.std(list(self.psi_history))),
                    'min': float(np.min(list(self.psi_history))),
                    'max': float(np.max(list(self.psi_history)))
                },
                'pe': {
                    'mean': float(np.mean(list(self.pe_history))),
                    'std': float(np.std(list(self.pe_history))),
                    'p95': float(np.percentile(list(self.pe_history), 95)),
                    'max': float(np.max(list(self.pe_history)))
                },
                'h': {
                    'mean': float(np.mean(list(self.h_history))),
                    'std': float(np.std(list(self.h_history))),
                    'p95': float(np.percentile(list(self.h_history), 95)),
                    'max': float(np.max(list(self.h_history)))
                }
            },
            'interventions': {
                'total': self._intervention_count,
                'last_step': self._last_intervention_step,
                'current_red_flag': self._red_flag,
                'current_reason': self._red_flag_reason
            }
        }
