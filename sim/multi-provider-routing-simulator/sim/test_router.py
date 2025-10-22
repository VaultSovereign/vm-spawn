#!/usr/bin/env python3
"""
Unit tests for VaultMesh Multi-Provider Router
Tests routing filter logic: price, latency, reputation, capacity
"""

import sys
import os

# Add sim directory to path for imports
sys.path.insert(0, os.path.dirname(__file__))

from sim import ProviderState, Router, Request


def test_filters_price():
    """Test that router filters providers by price constraints."""
    p = ProviderState(
        id="test-provider",
        name="Test Provider",
        bridge="rest_api",
        regions=["eu-west-1"],
        gpu_types=["A100"],
        credits_per_hour={"A100": 1.0},
        price_usd_per_hour={"A100": 2.0},
        base_latency_ms=300,
        capacity_gpu_hours_per_step=100,
        reputation=80,
    )
    router = Router({"test-provider": p}, usd_per_credit=1.8)
    router.reset_step()

    # Request with max_price lower than provider price -> should be rejected
    req = Request(
        step=0,
        tenant_id="tenant-test",
        region="eu-west-1",
        workload_type="llm_infer",
        gpu_type="A100",
        gpu_hours=1.0,
        max_price=1.0,  # Provider charges 2.0
        max_latency_ms=400,
        min_reputation=50,
        weights={"price": 1, "latency": 0, "reputation": 0, "availability": 0},
    )
    decision = router.route(req)
    assert not decision.accepted, "Request should be rejected due to high price"
    assert decision.reason == "no_viable_provider"

    # Request with acceptable max_price -> should be accepted
    req.max_price = 3.0
    router.reset_step()
    decision = router.route(req)
    assert decision.accepted, "Request should be accepted with acceptable price"
    assert decision.provider_id == "test-provider"
    print("✓ Price filter test passed")


def test_filters_latency():
    """Test that router filters providers by latency constraints."""
    p = ProviderState(
        id="test-provider",
        name="Test Provider",
        bridge="rest_api",
        regions=["eu-west-1"],
        gpu_types=["A100"],
        credits_per_hour={"A100": 1.0},
        price_usd_per_hour={"A100": 2.0},
        base_latency_ms=300,
        capacity_gpu_hours_per_step=100,
        reputation=80,
    )
    router = Router({"test-provider": p}, usd_per_credit=1.8)
    router.reset_step()

    # Request with max_latency lower than provider latency -> should be rejected
    req = Request(
        step=0,
        tenant_id="tenant-test",
        region="eu-west-1",
        workload_type="llm_infer",
        gpu_type="A100",
        gpu_hours=1.0,
        max_price=3.0,
        max_latency_ms=200,  # Provider has 300ms latency
        min_reputation=50,
        weights={"price": 0, "latency": 1, "reputation": 0, "availability": 0},
    )
    decision = router.route(req)
    assert not decision.accepted, "Request should be rejected due to high latency"
    assert decision.reason == "no_viable_provider"

    # Request with acceptable max_latency -> should be accepted
    req.max_latency_ms = 400
    router.reset_step()
    decision = router.route(req)
    assert decision.accepted, "Request should be accepted with acceptable latency"
    assert decision.provider_id == "test-provider"
    print("✓ Latency filter test passed")


def test_filters_reputation():
    """Test that router filters providers by reputation constraints."""
    p = ProviderState(
        id="test-provider",
        name="Test Provider",
        bridge="rest_api",
        regions=["eu-west-1"],
        gpu_types=["A100"],
        credits_per_hour={"A100": 1.0},
        price_usd_per_hour={"A100": 2.0},
        base_latency_ms=300,
        capacity_gpu_hours_per_step=100,
        reputation=80,
    )
    router = Router({"test-provider": p}, usd_per_credit=1.8)
    router.reset_step()

    # Request with min_reputation higher than provider reputation -> should be rejected
    req = Request(
        step=0,
        tenant_id="tenant-test",
        region="eu-west-1",
        workload_type="llm_infer",
        gpu_type="A100",
        gpu_hours=1.0,
        max_price=3.0,
        max_latency_ms=400,
        min_reputation=90,  # Provider has reputation 80
        weights={"price": 0, "latency": 0, "reputation": 1, "availability": 0},
    )
    decision = router.route(req)
    assert not decision.accepted, "Request should be rejected due to low reputation"
    assert decision.reason == "no_viable_provider"

    # Request with acceptable min_reputation -> should be accepted
    req.min_reputation = 50
    router.reset_step()
    decision = router.route(req)
    assert decision.accepted, "Request should be accepted with acceptable reputation"
    assert decision.provider_id == "test-provider"
    print("✓ Reputation filter test passed")


def test_filters_capacity():
    """Test that router respects provider capacity constraints."""
    p = ProviderState(
        id="test-provider",
        name="Test Provider",
        bridge="rest_api",
        regions=["eu-west-1"],
        gpu_types=["A100"],
        credits_per_hour={"A100": 1.0},
        price_usd_per_hour={"A100": 2.0},
        base_latency_ms=300,
        capacity_gpu_hours_per_step=10,  # Small capacity
        reputation=80,
    )
    router = Router({"test-provider": p}, usd_per_credit=1.8)
    router.reset_step()

    # Request that exceeds capacity -> should be rejected
    req = Request(
        step=0,
        tenant_id="tenant-test",
        region="eu-west-1",
        workload_type="llm_infer",
        gpu_type="A100",
        gpu_hours=20.0,  # Exceeds capacity of 10
        max_price=3.0,
        max_latency_ms=400,
        min_reputation=50,
        weights={"price": 1, "latency": 0, "reputation": 0, "availability": 0},
    )
    decision = router.route(req)
    assert not decision.accepted, "Request should be rejected due to insufficient capacity"
    assert decision.reason == "no_viable_provider"

    # Request within capacity -> should be accepted
    req.gpu_hours = 5.0
    router.reset_step()
    decision = router.route(req)
    assert decision.accepted, "Request should be accepted with sufficient capacity"
    assert decision.provider_id == "test-provider"
    print("✓ Capacity filter test passed")


def test_capacity_depletion():
    """Test that router tracks capacity depletion across multiple requests."""
    p = ProviderState(
        id="test-provider",
        name="Test Provider",
        bridge="rest_api",
        regions=["eu-west-1"],
        gpu_types=["A100"],
        credits_per_hour={"A100": 1.0},
        price_usd_per_hour={"A100": 2.0},
        base_latency_ms=300,
        capacity_gpu_hours_per_step=10,
        reputation=80,
    )
    router = Router({"test-provider": p}, usd_per_credit=1.8)
    router.reset_step()

    req = Request(
        step=0,
        tenant_id="tenant-test",
        region="eu-west-1",
        workload_type="llm_infer",
        gpu_type="A100",
        gpu_hours=6.0,
        max_price=3.0,
        max_latency_ms=400,
        min_reputation=50,
        weights={"price": 1, "latency": 0, "reputation": 0, "availability": 0},
    )

    # First request should succeed
    decision1 = router.route(req)
    assert decision1.accepted, "First request should be accepted"

    # Second request should fail (only 4 GPU hours remaining)
    decision2 = router.route(req)
    assert not decision2.accepted, "Second request should be rejected (capacity depleted)"
    print("✓ Capacity depletion test passed")


def test_region_filtering():
    """Test that router filters providers by region compatibility."""
    p = ProviderState(
        id="test-provider",
        name="Test Provider",
        bridge="rest_api",
        regions=["us-west-2"],  # Only US region
        gpu_types=["A100"],
        credits_per_hour={"A100": 1.0},
        price_usd_per_hour={"A100": 2.0},
        base_latency_ms=300,
        capacity_gpu_hours_per_step=100,
        reputation=80,
    )
    router = Router({"test-provider": p}, usd_per_credit=1.8)
    router.reset_step()

    # Request from incompatible region -> should be rejected
    req = Request(
        step=0,
        tenant_id="tenant-test",
        region="eu-west-1",  # Provider doesn't serve this region
        workload_type="llm_infer",
        gpu_type="A100",
        gpu_hours=1.0,
        max_price=3.0,
        max_latency_ms=400,
        min_reputation=50,
        weights={"price": 1, "latency": 0, "reputation": 0, "availability": 0},
    )
    decision = router.route(req)
    assert not decision.accepted, "Request should be rejected due to region mismatch"
    assert decision.reason == "no_viable_provider"

    # Request from compatible region -> should be accepted
    req.region = "us-west-2"
    router.reset_step()
    decision = router.route(req)
    assert decision.accepted, "Request should be accepted with matching region"
    assert decision.provider_id == "test-provider"
    print("✓ Region filter test passed")


def test_gpu_type_filtering():
    """Test that router filters providers by GPU type support."""
    p = ProviderState(
        id="test-provider",
        name="Test Provider",
        bridge="rest_api",
        regions=["eu-west-1"],
        gpu_types=["A100"],  # Only supports A100
        credits_per_hour={"A100": 1.0},
        price_usd_per_hour={"A100": 2.0},
        base_latency_ms=300,
        capacity_gpu_hours_per_step=100,
        reputation=80,
    )
    router = Router({"test-provider": p}, usd_per_credit=1.8)
    router.reset_step()

    # Request for unsupported GPU type -> should be rejected
    req = Request(
        step=0,
        tenant_id="tenant-test",
        region="eu-west-1",
        workload_type="llm_training",
        gpu_type="H100",  # Provider doesn't have H100
        gpu_hours=1.0,
        max_price=5.0,
        max_latency_ms=400,
        min_reputation=50,
        weights={"price": 1, "latency": 0, "reputation": 0, "availability": 0},
    )
    decision = router.route(req)
    assert not decision.accepted, "Request should be rejected due to GPU type mismatch"
    assert decision.reason == "no_viable_provider"

    # Request for supported GPU type -> should be accepted
    req.gpu_type = "A100"
    router.reset_step()
    decision = router.route(req)
    assert decision.accepted, "Request should be accepted with matching GPU type"
    assert decision.provider_id == "test-provider"
    print("✓ GPU type filter test passed")


def run_all_tests():
    """Run all router tests."""
    print("🧪 Running VaultMesh Router Unit Tests\n")

    tests = [
        test_filters_price,
        test_filters_latency,
        test_filters_reputation,
        test_filters_capacity,
        test_capacity_depletion,
        test_region_filtering,
        test_gpu_type_filtering,
    ]

    passed = 0
    failed = 0

    for test in tests:
        try:
            test()
            passed += 1
        except AssertionError as e:
            print(f"✗ {test.__name__} failed: {e}")
            failed += 1
        except Exception as e:
            print(f"✗ {test.__name__} errored: {e}")
            failed += 1

    print(f"\n{'='*50}")
    print(f"Tests: {passed} passed, {failed} failed")
    print(f"{'='*50}")

    return failed == 0


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
