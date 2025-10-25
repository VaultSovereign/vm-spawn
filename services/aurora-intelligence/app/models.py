"""Pydantic models for Aurora Intelligence API"""

from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional


class Candidate(BaseModel):
    """Provider/SKU candidate for routing decision"""
    provider: str = Field(..., description="Provider ID (e.g., 'akash', 'vast')")
    sku: str = Field(..., description="SKU identifier")
    metadata: Optional[Dict[str, Any]] = Field(default_factory=dict, description="Additional provider metadata")


class DecisionRequest(BaseModel):
    """Request for AI routing decision"""
    task_id: str = Field(..., description="Unique task identifier")
    context: Dict[str, Any] = Field(..., description="Task context (cpu, memory, latency, region, etc.)")
    candidates: List[Candidate] = Field(..., description="Available provider candidates")


class DecisionResponse(BaseModel):
    """AI routing decision response"""
    task_id: str
    chosen: Dict[str, Any] = Field(..., description="Selected candidate")
    score: float = Field(..., description="Confidence score")
    trace_id: str = Field(..., description="Decision trace ID for feedback")
    explanations: Dict[str, float] = Field(..., description="Explainability metrics")


class FeedbackOutcome(BaseModel):
    """Outcome metrics for feedback loop"""
    latency_ms: Optional[float] = None
    cost: Optional[float] = None
    failures: Optional[int] = 0
    slo_hit: Optional[bool] = None
    custom_metrics: Optional[Dict[str, float]] = Field(default_factory=dict)


class Feedback(BaseModel):
    """Feedback for Q-learning update"""
    trace_id: str = Field(..., description="Decision trace ID")
    outcome: FeedbackOutcome = Field(..., description="Observed outcome metrics")


class StatusResponse(BaseModel):
    """Service status and model metrics"""
    uptime_seconds: float
    model: Dict[str, Any]
    cache: Dict[str, Any]
    healthy: bool


class HealthResponse(BaseModel):
    """Health check response"""
    status: str
    timestamp: float
