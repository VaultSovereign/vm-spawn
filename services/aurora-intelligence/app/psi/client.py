"""
Psi-Field Client with caching

Fetches consciousness metrics from Psi-field service with TTL-based caching
to avoid overwhelming the service with requests.
"""

import time
import requests
from typing import Dict, Any, Optional, Tuple
from ..config import settings


class PsiClient:
    """
    Cached client for Psi-field consciousness metrics

    Implements simple time-based caching to reduce load on Psi-field service
    while ensuring fresh metrics for decision-making.
    """

    def __init__(self, base_url: Optional[str] = None, ttl: Optional[int] = None):
        """
        Initialize Psi-field client

        Args:
            base_url: Psi-field service URL (defaults to settings.PSI_URL)
            ttl: Cache TTL in seconds (defaults to settings.CACHE_TTL_S)
        """
        self.base_url = base_url or settings.PSI_URL
        self.ttl = ttl or settings.CACHE_TTL_S
        self.cache: Tuple[float, Dict[str, Any]] = (0.0, {})
        self.hits = 0
        self.misses = 0
        self.errors = 0

    def read(self) -> Dict[str, Any]:
        """
        Read Psi-field metrics with caching

        Returns:
            Psi metrics dict (Psi, C, U, Phi, H, PE, etc.)
            Falls back to default values if service unavailable
        """
        cache_time, cache_data = self.cache

        # Check cache validity
        if time.time() - cache_time < self.ttl:
            self.hits += 1
            return cache_data

        # Cache miss - fetch fresh data
        self.misses += 1
        try:
            response = requests.get(
                f"{self.base_url}/state",
                timeout=2
            )
            response.raise_for_status()
            data = response.json()

            # Update cache
            self.cache = (time.time(), data)
            return data

        except Exception as e:
            self.errors += 1
            # Graceful fallback: return cached data if available, else defaults
            if cache_data:
                return cache_data
            return self._get_default_metrics()

    def _get_default_metrics(self) -> Dict[str, Any]:
        """
        Default Psi metrics for fallback

        Returns neutral consciousness metrics when service is unavailable
        """
        return {
            "Psi": 0.5,          # Neutral consciousness density
            "C": 0.5,            # Neutral continuity
            "U": 0.0,            # No futurity
            "Phi": 0.5,          # Neutral phase coherence
            "H": 1.0,            # Medium entropy
            "PE": 0.0,           # No prediction error
            "M": 0.0,            # No memory magnitude
            "density": 0.5,      # Alias for Psi
            "coherence": 0.5,    # Alias for Phi
            "timestamp": time.time(),
            "_fallback": True,   # Indicator that these are defaults
        }

    def invalidate_cache(self):
        """Force cache refresh on next read()"""
        self.cache = (0.0, {})

    def get_stats(self) -> Dict[str, Any]:
        """
        Get client statistics

        Returns:
            Stats dict with cache metrics
        """
        cache_time, cache_data = self.cache
        cache_age = time.time() - cache_time if cache_time > 0 else None

        total_requests = self.hits + self.misses
        hit_rate = self.hits / total_requests if total_requests > 0 else 0.0

        return {
            "cache_hits": self.hits,
            "cache_misses": self.misses,
            "cache_errors": self.errors,
            "cache_hit_rate": hit_rate,
            "cache_age_seconds": cache_age,
            "cache_valid": cache_age < self.ttl if cache_age else False,
            "cache_ttl": self.ttl,
        }

    def health_check(self) -> bool:
        """
        Check if Psi-field service is reachable

        Returns:
            True if service responds to health endpoint
        """
        try:
            response = requests.get(
                f"{self.base_url}/health",
                timeout=2
            )
            return response.status_code == 200
        except Exception:
            return False
