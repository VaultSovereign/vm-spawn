"""
Kalman-like Backend for PSI-Field
---------------------------------
Improved predictor with state estimation and noise modeling
"""

import numpy as np
from typing import Dict, Any, Tuple, Optional

class KalmanBackend:
    """
    Kalman-inspired backend for better prediction error and futurity.
    Uses a simple state-space model with process and observation noise.
    """
    
    def __init__(self, input_dim: int = 16, latent_dim: int = 32):
        """
        Initialize Kalman backend
        
        Args:
            input_dim: Dimension of input observations
            latent_dim: Dimension of latent state
        """
        self.input_dim = input_dim
        self.latent_dim = latent_dim
        
        # State transition matrix (A)
        self.A = np.random.randn(latent_dim, latent_dim) * 0.1
        self.A += np.eye(latent_dim) * 0.9  # Diagonal dominance for stability
        
        # Observation matrix (C)
        self.C = np.random.randn(input_dim, latent_dim) * 0.1
        
        # Process noise covariance (Q)
        self.Q = np.eye(latent_dim) * 0.01
        
        # Observation noise covariance (R)
        self.R = np.eye(input_dim) * 0.1
        
        # State estimate covariance (P)
        self.P = np.eye(latent_dim) * 1.0
        
        # Current state estimate
        self.z = np.zeros(latent_dim)
        
        # Innovation (for PE calculation)
        self.innovation = 0.0
        
        # Learning rate for online adaptation
        self.lr = 0.01
    
    def encode(self, x: np.ndarray) -> np.ndarray:
        """
        Encode observation to latent state using Kalman update
        
        Args:
            x: Input observation (input_dim,)
        
        Returns:
            z: Updated latent state (latent_dim,)
        """
        # Prediction step
        z_pred = self.A @ self.z
        P_pred = self.A @ self.P @ self.A.T + self.Q
        
        # Observation prediction
        x_pred = self.C @ z_pred
        
        # Innovation (prediction error)
        y = x - x_pred
        self.innovation = np.linalg.norm(y)
        
        # Innovation covariance
        S = self.C @ P_pred @ self.C.T + self.R
        
        # Kalman gain
        K = P_pred @ self.C.T @ np.linalg.inv(S)
        
        # Update step
        self.z = z_pred + K @ y
        self.P = (np.eye(self.latent_dim) - K @ self.C) @ P_pred
        
        return self.z.copy()
    
    def predict(self, z: np.ndarray, steps: int = 1) -> np.ndarray:
        """
        Predict future latent states
        
        Args:
            z: Current latent state (latent_dim,)
            steps: Number of steps to predict ahead
        
        Returns:
            z_future: Predicted latent state (latent_dim,)
        """
        z_future = z.copy()
        for _ in range(steps):
            z_future = self.A @ z_future
        return z_future
    
    def decode(self, z: np.ndarray) -> np.ndarray:
        """
        Decode latent state to observation space
        
        Args:
            z: Latent state (latent_dim,)
        
        Returns:
            x: Reconstructed observation (input_dim,)
        """
        return self.C @ z
    
    def adapt(self, x: np.ndarray, z: np.ndarray):
        """
        Online adaptation of transition matrix based on observed data
        
        Args:
            x: Observed input (input_dim,)
            z: Current latent state (latent_dim,)
        """
        # Predict next observation
        z_next = self.A @ z
        x_pred = self.C @ z_next
        
        # Compute error
        error = x - x_pred
        
        # Gradient descent update on A (simplified)
        # ∂L/∂A = -2 * error @ C @ z^T
        grad_A = -2 * self.C.T @ error[:, None] @ z[None, :]
        self.A += self.lr * grad_A.T
        
        # Keep A stable (clip eigenvalues)
        eigvals = np.linalg.eigvals(self.A)
        if np.max(np.abs(eigvals)) > 0.99:
            self.A *= 0.99 / np.max(np.abs(eigvals))
    
    def get_prediction_error(self) -> float:
        """Get the current innovation magnitude (prediction error)"""
        return float(self.innovation)
    
    def reset_state(self):
        """Reset state estimate and covariance"""
        self.z = np.zeros(self.latent_dim)
        self.P = np.eye(self.latent_dim) * 1.0
        self.innovation = 0.0
    
    def increase_noise(self, factor: float = 1.5):
        """Increase process noise (for Nigredo intervention)"""
        self.Q *= factor
        self.R *= factor
    
    def decrease_noise(self, factor: float = 0.7):
        """Decrease process noise (for Albedo intervention)"""
        self.Q *= factor
        self.R *= factor
