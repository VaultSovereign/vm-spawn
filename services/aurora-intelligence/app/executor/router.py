"""
Executor - Calls Aurora Router API to execute routing decisions

The Executor is responsible for translating AI decisions into actual
provider routing calls via the Aurora Router service.
"""

import requests
from typing import Dict, Any, Optional
from ..config import settings


class ExecutorError(Exception):
    """Executor-specific errors"""
    pass


def route(task_id: str, choice: Dict[str, Any], timeout: int = 5) -> Dict[str, Any]:
    """
    Execute routing decision via Aurora Router

    Args:
        task_id: Task identifier
        choice: Selected candidate (provider, sku, metadata)
        timeout: Request timeout in seconds

    Returns:
        Router response with execution details

    Raises:
        ExecutorError: If routing fails
    """
    payload = {
        "task_id": task_id,
        "provider": choice.get("provider"),
        "sku": choice.get("sku"),
        "metadata": choice.get("metadata", {}),
    }

    try:
        response = requests.post(
            f"{settings.AURORA_ROUTER_URL}/route",
            json=payload,
            timeout=timeout,
            headers={"Content-Type": "application/json"}
        )
        response.raise_for_status()
        return response.json()

    except requests.exceptions.Timeout:
        raise ExecutorError(f"Aurora Router timeout after {timeout}s")
    except requests.exceptions.ConnectionError as e:
        raise ExecutorError(f"Aurora Router connection failed: {e}")
    except requests.exceptions.HTTPError as e:
        raise ExecutorError(f"Aurora Router HTTP error: {e.response.status_code}")
    except Exception as e:
        raise ExecutorError(f"Aurora Router execution failed: {e}")


def get_router_health(timeout: int = 3) -> Optional[Dict[str, Any]]:
    """
    Check Aurora Router health

    Returns:
        Health response dict or None if unhealthy
    """
    try:
        response = requests.get(
            f"{settings.AURORA_ROUTER_URL}/health",
            timeout=timeout
        )
        response.raise_for_status()
        return response.json()
    except Exception:
        return None
