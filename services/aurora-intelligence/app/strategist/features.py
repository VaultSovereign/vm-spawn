"""
Feature engineering for Q-learning state representation

Converts continuous context and Psi-field metrics into discrete state keys
for tabular Q-learning.
"""

from typing import Dict, Any


def featurize(context: Dict[str, Any], psi_metrics: Dict[str, Any]) -> str:
    """
    Convert context + Psi metrics into discrete state key

    Discretization strategy:
    - Region: categorical (as-is)
    - CPU: bucketed into 2, 4, 8, 16, 32+
    - Memory: bucketed into 8, 16, 32, 64, 128+ GB
    - Latency: bucketed into <50, 50-100, 100-200, 200+ ms
    - Psi coherence: rounded to 0.1 precision
    - Psi density: rounded to 0.1 precision

    Args:
        context: Task context (cpu, memory, latency_ms, region, etc.)
        psi_metrics: Psi-field metrics (coherence, density, etc.)

    Returns:
        State key string (e.g., "us-west|8|32|100|0.7|0.8")
    """
    # Extract and discretize context features
    region = context.get("region", "global")

    cpu = context.get("cpu", 4)
    cpu_bucket = discretize_cpu(cpu)

    memory_gb = context.get("memory_gb", context.get("mem", 16))
    if isinstance(memory_gb, str):
        # Parse "32Gi" format
        memory_gb = parse_memory(memory_gb)
    mem_bucket = discretize_memory(memory_gb)

    latency_ms = context.get("latency_ms", 100)
    lat_bucket = discretize_latency(latency_ms)

    # Extract and discretize Psi metrics
    coherence = psi_metrics.get("C", psi_metrics.get("coherence", 0.5))
    coherence_rounded = round(coherence, 1)

    density = psi_metrics.get("Psi", psi_metrics.get("density", 0.5))
    density_rounded = round(density, 1)

    # Construct state key
    state_key = f"{region}|{cpu_bucket}|{mem_bucket}|{lat_bucket}|{coherence_rounded}|{density_rounded}"
    return state_key


def discretize_cpu(cpu: int) -> str:
    """Bucket CPU cores"""
    if cpu <= 2:
        return "2"
    elif cpu <= 4:
        return "4"
    elif cpu <= 8:
        return "8"
    elif cpu <= 16:
        return "16"
    elif cpu <= 32:
        return "32"
    else:
        return "64+"


def discretize_memory(memory_gb: float) -> str:
    """Bucket memory in GB"""
    if memory_gb <= 8:
        return "8"
    elif memory_gb <= 16:
        return "16"
    elif memory_gb <= 32:
        return "32"
    elif memory_gb <= 64:
        return "64"
    elif memory_gb <= 128:
        return "128"
    else:
        return "256+"


def discretize_latency(latency_ms: float) -> str:
    """Bucket latency in ms"""
    if latency_ms < 50:
        return "<50"
    elif latency_ms < 100:
        return "50-100"
    elif latency_ms < 200:
        return "100-200"
    else:
        return "200+"


def parse_memory(mem_str: str) -> float:
    """Parse Kubernetes memory format (e.g., '32Gi', '16G', '512Mi')"""
    mem_str = mem_str.strip().upper()

    # Remove 'I' for binary units
    mem_str = mem_str.replace("I", "")

    # Extract number and unit
    if mem_str.endswith("G"):
        return float(mem_str[:-1])
    elif mem_str.endswith("M"):
        return float(mem_str[:-1]) / 1024
    elif mem_str.endswith("K"):
        return float(mem_str[:-1]) / (1024 * 1024)
    else:
        # Assume bytes
        return float(mem_str) / (1024 * 1024 * 1024)
