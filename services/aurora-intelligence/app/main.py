"""
Aurora Intelligence - AI Routing Control Plane

FastAPI service implementing Strategist/Executor/Auditor triad for
AI-enhanced multi-provider routing decisions.
"""

import time
import uuid
from fastapi import FastAPI, HTTPException, Response
from fastapi.responses import PlainTextResponse

from .config import settings
from .models import (
    DecisionRequest,
    DecisionResponse,
    Feedback,
    StatusResponse,
    HealthResponse
)
from .strategist.q_agent import QAgent
from .strategist.features import featurize
from .executor.router import route, ExecutorError, get_router_health
from .auditor.feedback import compute_reward, explain_reward
from .psi.client import PsiClient
from .store.decisions import store
from .telemetry import metrics

# Initialize FastAPI app
app = FastAPI(
    title="Aurora Intelligence",
    description="AI-enhanced routing control plane with Q-learning",
    version="0.1.0"
)

# Service start time
START_TIME = time.time()

# Initialize components
psi_client = PsiClient()

# Initialize Q-learning agent with dummy actions (will be updated per request)
agent = QAgent(
    actions=["0", "1", "2", "3"],  # Candidate indices
    alpha=settings.ALPHA,
    gamma=settings.GAMMA,
    epsilon=settings.EPSILON
)

# Update metrics on startup
metrics.epsilon.set(agent.epsilon)


@app.post("/decisions", response_model=DecisionResponse)
async def make_decision(request: DecisionRequest):
    """
    Make AI-enhanced routing decision

    Uses Strategist (Q-learning) + Psi-field context to select best provider,
    then executes via Aurora Router.
    """
    start_time = time.time()

    # Phase 1: Strategist - Get Psi metrics and featurize state
    strategist_start = time.time()

    psi_snapshot = psi_client.read()
    state_key = featurize(request.context, psi_snapshot)

    # Dynamically update agent actions based on candidates
    candidate_indices = [str(i) for i in range(len(request.candidates))]
    agent.actions = candidate_indices

    # Select action (candidate index) via Q-learning
    action_idx_str = agent.act(state_key, explore=True)
    action_idx = int(action_idx_str)

    # Get Q-value for chosen action
    q_value = agent.get_q_value(state_key, action_idx_str)

    strategist_duration = time.time() - strategist_start
    metrics.decision_latency.labels(phase="strategist").observe(strategist_duration)

    # Phase 2: Executor - Route via Aurora Router
    executor_start = time.time()

    chosen_candidate = request.candidates[action_idx]
    chosen_dict = chosen_candidate.model_dump()

    try:
        exec_response = route(request.task_id, chosen_dict)
        exec_score = exec_response.get("score", 0.0)
    except ExecutorError as e:
        # Executor failed - record but don't fail the decision
        exec_score = 0.0
        exec_response = {"error": str(e), "score": 0.0}

    executor_duration = time.time() - executor_start
    metrics.decision_latency.labels(phase="executor").observe(executor_duration)

    # Phase 3: Record trace
    trace_id = f"tr_{uuid.uuid4().hex[:16]}"

    store.save_trace(
        trace_id=trace_id,
        task_id=request.task_id,
        state_key=state_key,
        action=action_idx_str,
        chosen=chosen_dict,
        metadata={
            "q_value": q_value,
            "psi_snapshot": psi_snapshot,
            "epsilon": agent.epsilon,
            "exec_response": exec_response
        }
    )

    # Record metrics
    exploration = "explore" if action_idx_str != agent.get_best_q(state_key)[0] else "exploit"
    metrics.decisions_total.labels(
        provider=chosen_candidate.provider,
        exploration=exploration
    ).inc()

    total_duration = time.time() - start_time
    metrics.decision_latency.labels(phase="total").observe(total_duration)

    # Response
    return DecisionResponse(
        task_id=request.task_id,
        chosen=chosen_dict,
        score=exec_score,
        trace_id=trace_id,
        explanations={
            "q_value": q_value,
            "psi_coherence": psi_snapshot.get("C", 0.5),
            "psi_density": psi_snapshot.get("Psi", 0.5),
            "exploration_mode": 1.0 if exploration == "explore" else 0.0,
        }
    )


@app.post("/feedback")
async def receive_feedback(feedback: Feedback):
    """
    Receive feedback and update Q-learning agent

    Closes the learning loop by computing reward from observed outcomes
    and updating the Q-table.
    """
    start_time = time.time()

    # Retrieve trace
    trace = store.get_trace(feedback.trace_id)
    if not trace:
        raise HTTPException(status_code=404, detail=f"Trace {feedback.trace_id} not found")

    # Compute reward
    reward = compute_reward(feedback.outcome)
    metrics.rewards.observe(reward)

    # Get current Psi state for next_state
    psi_snapshot = psi_client.read()

    # For simplicity, use same context to featurize next_state
    # In production, this should come from the actual next task context
    state_key = trace["state_key"]
    metadata = trace.get("metadata")
    if metadata:
        import json
        metadata = json.loads(metadata) if isinstance(metadata, str) else metadata
        old_psi = metadata.get("psi_snapshot", {})
        next_state_key = featurize(
            {"region": "global"},  # Placeholder
            psi_snapshot
        )
    else:
        next_state_key = state_key  # Fallback

    # Update Q-table
    action = trace["action"]
    agent.update(state_key, action, reward, next_state_key)
    metrics.q_updates_total.inc()

    # Update trace with feedback
    store.update_feedback(feedback.trace_id, reward, next_state_key)

    # Update metrics
    outcome_label = "success" if feedback.outcome.slo_hit else "failure"
    metrics.feedback_total.labels(outcome=outcome_label).inc()

    feedback_duration = time.time() - start_time
    metrics.feedback_latency.observe(feedback_duration)

    # Explain reward
    explanation = explain_reward(feedback.outcome, reward)

    return {
        "updated": True,
        "reward": reward,
        "explanation": explanation,
        "q_updates": agent.updates
    }


@app.get("/status", response_model=StatusResponse)
async def get_status():
    """Get service status and model metrics"""
    uptime = time.time() - START_TIME

    # Update gauge metrics
    agent_stats = agent.get_stats()
    metrics.epsilon.set(agent.epsilon)
    metrics.q_table_size.set(agent_stats["total_state_action_pairs"])

    psi_stats = psi_client.get_stats()
    metrics.psi_cache_hits.inc(psi_stats["cache_hits"])
    metrics.psi_cache_misses.inc(psi_stats["cache_misses"])
    metrics.psi_cache_errors.inc(psi_stats["cache_errors"])

    store_stats = store.get_stats()
    metrics.trace_store_size.set(store_stats["total_traces"])
    metrics.trace_store_feedback_rate.set(store_stats["feedback_rate"])

    return StatusResponse(
        uptime_seconds=uptime,
        model=agent_stats,
        cache=psi_stats,
        healthy=True
    )


@app.get("/healthz", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="healthy",
        timestamp=time.time()
    )


@app.get("/metrics")
async def prometheus_metrics():
    """Prometheus metrics endpoint"""
    return Response(
        content=metrics.get_metrics(),
        media_type=metrics.get_content_type()
    )


@app.get("/")
async def root():
    """Service info"""
    return {
        "service": "Aurora Intelligence",
        "version": "0.1.0",
        "description": "AI-enhanced routing control plane",
        "endpoints": {
            "decisions": "/decisions",
            "feedback": "/feedback",
            "status": "/status",
            "health": "/healthz",
            "metrics": "/metrics"
        }
    }


# Startup event
@app.on_event("startup")
async def startup_event():
    """Initialize service on startup"""
    print("Aurora Intelligence starting...")
    print(f"  Psi-field: {settings.PSI_URL}")
    print(f"  Aurora Router: {settings.AURORA_ROUTER_URL}")
    print(f"  Store: {settings.STORE_FILE}")
    print(f"  Q-learning: α={settings.ALPHA}, γ={settings.GAMMA}, ε={settings.EPSILON}")

    # Check service health
    if psi_client.health_check():
        print("  ✓ Psi-field reachable")
    else:
        print("  ⚠ Psi-field unreachable (will use fallback)")

    if get_router_health():
        print("  ✓ Aurora Router reachable")
    else:
        print("  ⚠ Aurora Router unreachable")

    print(f"Aurora Intelligence ready on port {settings.PORT}")
