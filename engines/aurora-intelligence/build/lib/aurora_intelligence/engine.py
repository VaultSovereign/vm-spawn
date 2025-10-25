"""
RoutingEngine — Main Entry Point

Orchestrates Strategist, Executor, and Auditor for end-to-end routing intelligence.
"""

from typing import Dict, List, Optional, Tuple
import httpx

from .strategist import Strategist, WorkloadContext, ProviderState
from .executor import Executor
from .auditor import Auditor


class RoutingEngine:
    """
    Main Aurora Intelligence Engine.

    Coordinates:
    - Strategist: Q-learning decision making
    - Executor: Outcome tracking and reward computation
    - Auditor: Constraint validation and audit trail

    Integrates with:
    - Ψ-Field: Consciousness metrics for adaptive exploration
    - Aurora Router: Provides routing recommendations
    """

    def __init__(
        self,
        psi_field_url: Optional[str] = None,
        strict_audit: bool = False,
        auto_save: bool = True,
        model_path: str = "/tmp/aurora_q_table.json",
    ):
        self.strategist = Strategist()
        self.executor = Executor()
        self.auditor = Auditor(strict_mode=strict_audit)

        self.psi_field_url = psi_field_url
        self.auto_save = auto_save
        self.model_path = model_path

        # Try to load existing Q-table
        try:
            self.strategist.load(model_path)
        except FileNotFoundError:
            pass  # Start fresh

    async def fetch_psi_metrics(self) -> Optional[Dict]:
        """
        Fetch consciousness metrics from Ψ-Field service.

        Returns:
            Dict with psi_density, psi_coherence, psi_entropy (or None if unavailable)
        """
        if not self.psi_field_url:
            return None

        try:
            async with httpx.AsyncClient(timeout=2.0) as client:
                response = await client.get(f"{self.psi_field_url}/api/metrics")
                response.raise_for_status()
                return response.json()
        except Exception:
            return None

    def decide(
        self,
        context: Dict,
        providers: List[Dict],
        constraints: Optional[Dict] = None,
        psi_metrics: Optional[Dict] = None,
    ) -> Tuple[Optional[str], Dict]:
        """
        Make a routing decision.

        Args:
            context: Workload context (workload_type, gpu_type, region, etc.)
            providers: List of available providers with their capabilities
            constraints: Optional constraints (max_price, max_latency, etc.)
            psi_metrics: Optional Ψ-field metrics (can be fetched automatically)

        Returns:
            (provider_id, decision_metadata): Selected provider and decision details
        """
        # Parse context
        workload_context = WorkloadContext(
            workload_type=context["workload_type"],
            gpu_type=context["gpu_type"],
            region=context["region"],
            gpu_hours=context.get("gpu_hours", 1.0),
            max_price=context.get("max_price"),
            max_latency_ms=context.get("max_latency_ms"),
            min_reputation=context.get("min_reputation"),
        )

        # Parse providers
        provider_states = [
            ProviderState(
                provider_id=p["provider_id"],
                price_usd_per_hour=p["price_usd_per_hour"],
                latency_ms=p["latency_ms"],
                reputation=p["reputation"],
                capacity_available=p.get("capacity_available", float('inf')),
                gpu_types=p.get("gpu_types", []),
                regions=p.get("regions", []),
            )
            for p in providers
        ]

        # Filter providers by constraints
        if constraints:
            filtered_providers = []
            for p in provider_states:
                provider_dict = {
                    "price_usd_per_hour": p.price_usd_per_hour,
                    "latency_ms": p.latency_ms,
                    "reputation": p.reputation,
                    "capacity_available": p.capacity_available,
                    "gpu_types": p.gpu_types,
                    "regions": p.regions,
                }
                is_valid, _ = self.auditor.validate_decision(
                    decision_id="pre_filter",
                    state_key="pre_filter",
                    provider_id=p.provider_id,
                    provider_state=provider_dict,
                    constraints=constraints,
                )
                if is_valid:
                    filtered_providers.append(p)
            provider_states = filtered_providers

        if not provider_states:
            return None, {"reason": "no_viable_providers_after_filtering"}

        # Get Ψ-field consciousness density for adaptive exploration
        psi_density = None
        if psi_metrics:
            psi_density = psi_metrics.get("psi_density")

        # Strategist: Recommend provider
        provider_id, metadata = self.strategist.recommend(
            context=workload_context,
            providers=provider_states,
            psi_density=psi_density,
        )

        if not provider_id:
            return None, metadata

        # Executor: Record decision
        decision_id = self.executor.record_decision(
            state_key=metadata["state_key"],
            provider_id=provider_id,
            context=context,
            metadata=metadata,
        )

        # Auditor: Validate decision
        selected_provider = next(p for p in provider_states if p.provider_id == provider_id)
        provider_dict = {
            "price_usd_per_hour": selected_provider.price_usd_per_hour,
            "latency_ms": selected_provider.latency_ms,
            "reputation": selected_provider.reputation,
            "capacity_available": selected_provider.capacity_available,
            "gpu_types": selected_provider.gpu_types,
            "regions": selected_provider.regions,
        }

        is_valid, violations = self.auditor.validate_decision(
            decision_id=decision_id,
            state_key=metadata["state_key"],
            provider_id=provider_id,
            provider_state=provider_dict,
            constraints=constraints or {},
        )

        # Add decision metadata
        metadata["decision_id"] = decision_id
        metadata["validated"] = is_valid
        metadata["violations"] = [v.value for v in violations]

        # Auto-save Q-table periodically
        if self.auto_save and self.strategist.decision_count % 10 == 0:
            self.strategist.save(self.model_path)

        return provider_id, metadata

    def feedback(
        self,
        decision_id: str,
        success: bool,
        actual_cost_usd: float,
        actual_latency_ms: float,
        actual_reputation: Optional[float] = None,
        error_reason: Optional[str] = None,
    ) -> Optional[float]:
        """
        Provide feedback on a routing decision outcome.

        This triggers Q-learning updates based on actual reward.

        Args:
            decision_id: Decision identifier from decide()
            success: Whether routing was successful
            actual_cost_usd: Actual cost incurred
            actual_latency_ms: Actual latency experienced
            actual_reputation: Optional provider reputation score
            error_reason: Optional error reason if failed

        Returns:
            reward: Computed reward value (or None if decision not found)
        """
        # Executor: Record outcome and compute reward
        reward = self.executor.record_outcome(
            decision_id=decision_id,
            success=success,
            actual_cost_usd=actual_cost_usd,
            actual_latency_ms=actual_latency_ms,
            actual_reputation=actual_reputation,
            error_reason=error_reason,
        )

        if reward is None:
            return None

        # Retrieve decision details
        decision = self.executor.get_decision(decision_id)
        if not decision:
            return None

        # Strategist: Update Q-value
        self.strategist.update_q_value(
            state_key=decision.state_key,
            provider_id=decision.provider_id,
            reward=reward,
            next_state_key=None,  # Terminal state for now
        )

        # Decay exploration rate
        self.strategist.decay_epsilon()

        # Auto-save Q-table
        if self.auto_save:
            self.strategist.save(self.model_path)

        return reward

    def get_status(self) -> Dict:
        """Get engine status and statistics."""
        return {
            "strategist": self.strategist.get_stats(),
            "executor": self.executor.get_stats(),
            "auditor": self.auditor.get_stats(),
            "psi_field_connected": self.psi_field_url is not None,
            "model_path": self.model_path,
        }
