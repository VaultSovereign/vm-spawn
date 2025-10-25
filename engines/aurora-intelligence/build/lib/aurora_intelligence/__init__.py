"""
Aurora Intelligence Engine — Adaptive Multi-Cloud Routing Intelligence

Core RL-based decision engine for VaultMesh aurora-router Phase 3.
Not a service — a computational library.

Usage:
    from aurora_intelligence import Strategist, Executor, Auditor, RoutingEngine

    engine = RoutingEngine()
    decision = engine.decide(workload_context)
"""

__version__ = "1.0.0"

from .strategist import Strategist
from .executor import Executor
from .auditor import Auditor
from .engine import RoutingEngine

__all__ = [
    "Strategist",
    "Executor",
    "Auditor",
    "RoutingEngine",
]
