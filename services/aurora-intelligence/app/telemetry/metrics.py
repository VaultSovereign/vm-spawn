"""
Prometheus metrics for Aurora Intelligence

Tracks:
- Decision requests and latency
- Q-learning updates and epsilon
- Psi-field cache performance
- Feedback loop health
"""

from prometheus_client import (
    Counter,
    Histogram,
    Gauge,
    CollectorRegistry,
    generate_latest,
    CONTENT_TYPE_LATEST
)
from ..config import settings


# Create registry
registry = CollectorRegistry()
ns = settings.METRICS_NS

# Decision metrics
decisions_total = Counter(
    f"{ns}_decisions_total",
    "Total number of routing decisions made",
    ["provider", "exploration"],
    registry=registry
)

decision_latency = Histogram(
    f"{ns}_decision_latency_seconds",
    "Decision-making latency",
    ["phase"],  # strategist, executor, total
    registry=registry
)

# Q-learning metrics
q_updates_total = Counter(
    f"{ns}_q_updates_total",
    "Total number of Q-table updates",
    registry=registry
)

rewards = Histogram(
    f"{ns}_rewards",
    "Observed rewards from feedback",
    buckets=[-1.0, -0.5, 0.0, 0.5, 1.0],
    registry=registry
)

epsilon = Gauge(
    f"{ns}_epsilon",
    "Current exploration rate",
    registry=registry
)

q_table_size = Gauge(
    f"{ns}_q_table_size",
    "Number of state-action pairs in Q-table",
    registry=registry
)

# Psi-field cache metrics
psi_cache_hits = Counter(
    f"{ns}_psi_cache_hits_total",
    "Psi-field cache hits",
    registry=registry
)

psi_cache_misses = Counter(
    f"{ns}_psi_cache_misses_total",
    "Psi-field cache misses",
    registry=registry
)

psi_cache_errors = Counter(
    f"{ns}_psi_cache_errors_total",
    "Psi-field cache errors",
    registry=registry
)

# Feedback metrics
feedback_total = Counter(
    f"{ns}_feedback_total",
    "Total feedback received",
    ["outcome"],  # success, failure
    registry=registry
)

feedback_latency = Histogram(
    f"{ns}_feedback_latency_seconds",
    "Feedback processing latency",
    registry=registry
)

# Store metrics
trace_store_size = Gauge(
    f"{ns}_trace_store_size",
    "Number of decision traces stored",
    registry=registry
)

trace_store_feedback_rate = Gauge(
    f"{ns}_trace_store_feedback_rate",
    "Percentage of traces with feedback",
    registry=registry
)


def get_metrics() -> bytes:
    """
    Generate Prometheus metrics export

    Returns:
        Metrics in Prometheus text format
    """
    return generate_latest(registry)


def get_content_type() -> str:
    """Get Prometheus content type"""
    return CONTENT_TYPE_LATEST
