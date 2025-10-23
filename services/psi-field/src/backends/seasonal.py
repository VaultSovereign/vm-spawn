"""
Seasonal Backend for PSI-Field
------------------------------
Predictor with seasonal/circadian components for time-aware patterns
"""

import numpy as np
from typing import Dict, Any, Tuple, Optional
from datetime import datetime, timedelta

class SeasonalBackend:
    """
    Backend with seasonal decomposition for time-aware predictions.
    Captures daily/weekly patterns common in operational metrics.
    """
    
    def __init__(self, input_dim: int = 16, latent_dim: int = 32):
        """
        Initialize Seasonal backend
        
        Args:
            input_dim: Dimension of input observations
            latent_dim: Dimension of latent state
        """
        self.input_dim = input_dim
        self.latent_dim = latent_dim
        
        # Base transition matrix
        self.A = np.random.randn(latent_dim, latent_dim) * 0.1
        self.A += np.eye(latent_dim) * 0.8
        
        # Observation matrix
        self.C = np.random.randn(input_dim, latent_dim) * 0.1
        
        # Seasonal components (hourly, daily, weekly)
        self.seasonal_periods = {
            'hourly': 3600,      # 1 hour in seconds
            'daily': 86400,      # 24 hours
            'weekly': 604800     # 7 days
        }
        
        # Seasonal weights (learned online)
        self.seasonal_weights = {
            period: np.zeros((input_dim, 2))  # cos, sin components
            for period in self.seasonal_periods
        }
        
        # Current state
        self.z = np.zeros(latent_dim)
        
        # Trend component (EMA)
        self.trend = np.zeros(input_dim)
        self.trend_alpha = 0.1
        
        # Reference timestamp for seasonal calculation
        self.ref_time = datetime.now()
        self.current_time = datetime.now()
        
        # Prediction error tracking
        self.pe = 0.0
        
        # Learning rate
        self.lr = 0.01
    
    def _compute_seasonal_features(self, timestamp: datetime) -> Dict[str, np.ndarray]:
        """
        Compute cos/sin features for each seasonal period
        
        Args:
            timestamp: Current timestamp
        
        Returns:
            Dict mapping period name to [cos, sin] features
        """
        features = {}
        elapsed = (timestamp - self.ref_time).total_seconds()
        
        for name, period in self.seasonal_periods.items():
            phase = 2 * np.pi * (elapsed % period) / period
            features[name] = np.array([np.cos(phase), np.sin(phase)])
        
        return features
    
    def _apply_seasonal_adjustment(self, x: np.ndarray, timestamp: datetime) -> np.ndarray:
        """
        Apply seasonal components to observation
        
        Args:
            x: Input observation (input_dim,)
            timestamp: Current timestamp
        
        Returns:
            x_adjusted: Seasonally adjusted observation
        """
        seasonal_features = self._compute_seasonal_features(timestamp)
        
        adjustment = np.zeros(self.input_dim)
        for name, features in seasonal_features.items():
            # Add weighted seasonal component
            adjustment += self.seasonal_weights[name] @ features
        
        return x + adjustment
    
    def encode(self, x: np.ndarray, timestamp: Optional[datetime] = None) -> np.ndarray:
        """
        Encode observation with seasonal awareness
        
        Args:
            x: Input observation (input_dim,)
            timestamp: Optional timestamp (uses current time if None)
        
        Returns:
            z: Latent state (latent_dim,)
        """
        if timestamp is None:
            timestamp = datetime.now()
        
        self.current_time = timestamp
        
        # Remove trend
        x_detrended = x - self.trend
        
        # Update trend (EMA)
        self.trend = self.trend_alpha * x + (1 - self.trend_alpha) * self.trend
        
        # Apply seasonal adjustment
        x_adjusted = self._apply_seasonal_adjustment(x_detrended, timestamp)
        
        # Standard encoding
        self.z = np.tanh(self.C.T @ x_adjusted)
        
        return self.z.copy()
    
    def predict(self, z: np.ndarray, steps: int = 1, future_time: Optional[datetime] = None) -> np.ndarray:
        """
        Predict future latent state with seasonal awareness
        
        Args:
            z: Current latent state (latent_dim,)
            steps: Number of steps ahead
            future_time: Target timestamp for prediction
        
        Returns:
            z_future: Predicted latent state
        """
        # Predict base dynamics
        z_future = z.copy()
        for _ in range(steps):
            z_future = self.A @ z_future
        
        # If we have a future time, adjust for seasonal shift
        if future_time is not None:
            # Compute seasonal difference
            current_features = self._compute_seasonal_features(self.current_time)
            future_features = self._compute_seasonal_features(future_time)
            
            # Adjust prediction based on seasonal change
            seasonal_delta = np.zeros(self.input_dim)
            for name in self.seasonal_periods:
                delta_features = future_features[name] - current_features[name]
                seasonal_delta += self.seasonal_weights[name] @ delta_features
            
            # Project seasonal adjustment to latent space
            z_adjustment = self.C.T @ seasonal_delta
            z_future += z_adjustment * 0.5  # Scaled contribution
        
        return z_future
    
    def decode(self, z: np.ndarray) -> np.ndarray:
        """
        Decode latent state to observation space
        
        Args:
            z: Latent state (latent_dim,)
        
        Returns:
            x: Reconstructed observation (input_dim,)
        """
        return self.C @ z + self.trend
    
    def adapt(self, x: np.ndarray, z: np.ndarray):
        """
        Online adaptation of seasonal weights
        
        Args:
            x: Observed input (input_dim,)
            z: Current latent state (latent_dim,)
        """
        # Predict observation
        x_pred = self.decode(z)
        
        # Compute error
        error = x - x_pred
        self.pe = np.linalg.norm(error)
        
        # Update seasonal weights based on error
        seasonal_features = self._compute_seasonal_features(self.current_time)
        for name, features in seasonal_features.items():
            # Gradient: ∂L/∂w = -error @ features^T
            grad = -error[:, None] @ features[None, :]
            self.seasonal_weights[name] += self.lr * grad
    
    def get_prediction_error(self) -> float:
        """Get current prediction error"""
        return float(self.pe)
    
    def reset_state(self):
        """Reset state and trend"""
        self.z = np.zeros(self.latent_dim)
        self.trend = np.zeros(self.input_dim)
        self.pe = 0.0
    
    def increase_noise(self, factor: float = 1.5):
        """Increase learning rate (for Nigredo)"""
        self.lr *= factor
    
    def decrease_noise(self, factor: float = 0.7):
        """Decrease learning rate (for Albedo)"""
        self.lr *= factor
