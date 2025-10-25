"""Configuration management for Aurora Intelligence"""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Aurora Intelligence configuration"""

    # Service URLs
    AURORA_ROUTER_URL: str = "http://aurora-router.vaultmesh.svc.cluster.local:8080"
    PSI_URL: str = "http://psi-field.vaultmesh.svc.cluster.local:8000"

    # Storage
    STORE_FILE: str = "/data/decisions.db"

    # Q-Learning hyperparameters
    EPSILON: float = 0.1  # Exploration rate
    GAMMA: float = 0.92   # Discount factor
    ALPHA: float = 0.2    # Learning rate

    # Caching
    CACHE_TTL_S: int = 5  # Psi-field cache TTL

    # Telemetry
    METRICS_NS: str = "aurora_intelligence"
    PORT: int = 8080

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
