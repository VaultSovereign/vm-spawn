"""
Integration tests for RoutingEngine.
"""

import pytest
from aurora_intelligence import RoutingEngine, Strategist, Executor, Auditor


def test_engine_initialization():
    """Test engine initializes all components."""
    engine = RoutingEngine()

    assert isinstance(engine.strategist, Strategist)
    assert isinstance(engine.executor, Executor)
    assert isinstance(engine.auditor, Auditor)


def test_basic_routing_decision():
    """Test basic routing decision without constraints."""
    engine = RoutingEngine()

    context = {
        "workload_type": "llm_inference",
        "gpu_type": "a100",
        "region": "us-west",
        "gpu_hours": 2.0,
    }

    providers = [
        {
            "provider_id": "akash",
            "price_usd_per_hour": 2.50,
            "latency_ms": 120,
            "reputation": 95,
            "capacity_available": 100,
            "gpu_types": ["a100"],
            "regions": ["us-west"],
        },
        {
            "provider_id": "ionet",
            "price_usd_per_hour": 2.80,
            "latency_ms": 100,
            "reputation": 92,
            "capacity_available": 50,
            "gpu_types": ["a100"],
            "regions": ["us-west"],
        },
    ]

    provider_id, metadata = engine.decide(context, providers)

    assert provider_id in ["akash", "ionet"]
    assert "decision_id" in metadata
    assert "mode" in metadata
    assert metadata["mode"] in ["explore", "exploit"]


def test_routing_with_constraints():
    """Test routing decision respects constraints."""
    engine = RoutingEngine(strict_audit=True)

    context = {
        "workload_type": "llm_training",
        "gpu_type": "h100",
        "region": "eu-central",
        "gpu_hours": 5.0,
    }

    providers = [
        {
            "provider_id": "expensive_provider",
            "price_usd_per_hour": 5.0,  # Too expensive
            "latency_ms": 80,
            "reputation": 98,
            "capacity_available": 200,
            "gpu_types": ["h100"],
            "regions": ["eu-central"],
        },
        {
            "provider_id": "affordable_provider",
            "price_usd_per_hour": 3.0,  # Within budget
            "latency_ms": 120,
            "reputation": 90,
            "capacity_available": 150,
            "gpu_types": ["h100"],
            "regions": ["eu-central"],
        },
    ]

    constraints = {
        "max_price": 3.5,
        "max_latency_ms": 200,
        "min_reputation": 85,
    }

    provider_id, metadata = engine.decide(context, providers, constraints)

    # Should select affordable_provider (only one meeting constraints)
    assert provider_id == "affordable_provider"
    assert metadata["validated"]


def test_feedback_loop():
    """Test feedback updates Q-values."""
    engine = RoutingEngine()

    context = {
        "workload_type": "rendering",
        "gpu_type": "4090",
        "region": "us-east",
        "gpu_hours": 1.0,
    }

    providers = [
        {
            "provider_id": "vast",
            "price_usd_per_hour": 1.5,
            "latency_ms": 150,
            "reputation": 88,
            "capacity_available": 300,
            "gpu_types": ["4090"],
            "regions": ["us-east"],
        },
    ]

    # Make decision
    provider_id, metadata = engine.decide(context, providers)
    decision_id = metadata["decision_id"]

    # Provide feedback
    reward = engine.feedback(
        decision_id=decision_id,
        success=True,
        actual_cost_usd=1.45,
        actual_latency_ms=145,
        actual_reputation=89,
    )

    assert reward is not None
    assert isinstance(reward, float)

    # Verify Q-value was updated
    state_key = f"rendering:4090:us-east"
    assert state_key in engine.strategist.q_table
    assert "vast" in engine.strategist.q_table[state_key]


def test_no_viable_providers():
    """Test engine handles no viable providers gracefully."""
    engine = RoutingEngine()

    context = {
        "workload_type": "llm_inference",
        "gpu_type": "a100",
        "region": "us-west",
        "gpu_hours": 2.0,
    }

    # Empty provider list
    providers = []

    provider_id, metadata = engine.decide(context, providers)

    assert provider_id is None
    assert "reason" in metadata


def test_epsilon_decay():
    """Test epsilon decays over multiple decisions."""
    engine = RoutingEngine()

    initial_epsilon = engine.strategist.epsilon

    context = {
        "workload_type": "general",
        "gpu_type": "t4",
        "region": "global",
        "gpu_hours": 1.0,
    }

    providers = [
        {
            "provider_id": "provider1",
            "price_usd_per_hour": 1.0,
            "latency_ms": 100,
            "reputation": 90,
            "capacity_available": 100,
            "gpu_types": ["t4"],
            "regions": ["global"],
        },
    ]

    # Make multiple decisions with feedback
    for _ in range(10):
        provider_id, metadata = engine.decide(context, providers)
        engine.feedback(
            decision_id=metadata["decision_id"],
            success=True,
            actual_cost_usd=1.0,
            actual_latency_ms=100,
            actual_reputation=90,
        )

    final_epsilon = engine.strategist.epsilon

    # Epsilon should have decayed
    assert final_epsilon < initial_epsilon


def test_get_status():
    """Test status endpoint returns valid statistics."""
    engine = RoutingEngine()

    status = engine.get_status()

    assert "strategist" in status
    assert "executor" in status
    assert "auditor" in status
    assert "model_path" in status

    assert "epsilon" in status["strategist"]
    assert "decision_count" in status["strategist"]

    assert "total_decisions" in status["executor"]
    assert "success_rate" in status["executor"]

    assert "total_entries" in status["auditor"]
    assert "approval_rate" in status["auditor"]


@pytest.mark.asyncio
async def test_psi_field_integration():
    """Test Ψ-field metrics fetching (mocked)."""
    engine = RoutingEngine(psi_field_url="http://localhost:9999")

    # This will fail to connect (expected), but shouldn't crash
    psi_metrics = await engine.fetch_psi_metrics()

    # Should return None on connection failure
    assert psi_metrics is None
