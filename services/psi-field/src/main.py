"""
VaultMesh Ψ-Field API Service
-----------------------------
Provides a REST API for the Ψ-Field Evolution Algorithm with VaultMesh integration
"""

import os
import sys
import json
import time
import subprocess
import logging
import asyncio
import numpy as np
import uvicorn
from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel, Field
from typing import Dict, List, Any, Optional
from datetime import datetime

# Import local modules
from .federation import federation
from .mcp import MCPServer
from .mq import RabbitMQPublisher
try:
    from .guardian_advanced import AdvancedGuardian as Guardian
    GUARDIAN_KIND = "advanced"
except ImportError:
    from .guardian import Guardian
    GUARDIAN_KIND = "basic"
from .remembrancer_client import RemembrancerClient

# Add the vaultmesh_psi module to the Python path
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

# Import the VaultMesh Ψ-Field components
try:
    from vaultmesh_psi import psi_core
    from vaultmesh_psi.psi_core import Params, PsiEngine, SyntheticEnv
    # Backend selection
    if PSI_BACKEND == "kalman":
        from vaultmesh_psi.backends.kalman import KalmanBackend as BackendClass
    elif PSI_BACKEND == "seasonal":
        from vaultmesh_psi.backends.seasonal import SeasonalBackend as BackendClass
    else:
        from vaultmesh_psi.backends.simple import SimpleBackend as BackendClass
    IMPORT_SUCCESS = True
except ImportError:
    IMPORT_SUCCESS = False
    BackendClass = None
    logging.error("Could not import vaultmesh_psi module. Please ensure it is installed.")

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("psi-field-api")

# Global variables
psi_engine = None
guardian = None
remembrancer_client = None
mq_publisher = None
mcp_server = None

# Environment configuration
AGENT_ID = os.environ.get("AGENT_ID", "psi-field-agent")
RABBIT_ENABLED = os.environ.get("RABBIT_ENABLED", "0") == "1"
RABBIT_URL = os.environ.get("RABBIT_URL", "amqp://guest:guest@localhost:5672/")
RABBIT_EXCHANGE = os.environ.get("RABBIT_EXCHANGE", "swarm")
PSI_INPUT_DIM = int(os.environ.get("PSI_INPUT_DIM", "16"))
PSI_LATENT_DIM = int(os.environ.get("PSI_LATENT_DIM", "32"))
PSI_BACKEND = os.environ.get("PSI_BACKEND", "simple").lower()  # simple|kalman|seasonal

# Create FastAPI application
app = FastAPI(
    title="VaultMesh Ψ-Field API",
    description="REST API for the Ψ-Field Evolution Algorithm with VaultMesh integration",
    version="1.0.0",
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic models for requests and responses
class PsiParams(BaseModel):
    dt: float = Field(0.2, description="Integration step in seconds (default: 0.2)")
    W_r: float = Field(3.0, description="Retention window in seconds (default: 3.0)")
    H: float = Field(2.0, description="Rollout horizon in seconds (default: 2.0)")
    N: int = Field(8, description="Number of rollouts (default: 8)")
    C_w: int = Field(32, description="Working memory capacity (default: 32)")
    latent_dim: int = Field(32, description="Latent dimension (default: 32)")
    w1: float = Field(1.0, description="Weight for mnemonic capacity (default: 1.0)")
    w2: float = Field(0.8, description="Weight for continuity (default: 0.8)")
    w3: float = Field(0.6, description="Weight for futurity (default: 0.6)")
    w4: float = Field(0.6, description="Weight for phase coherence (default: 0.6)")
    w5: float = Field(0.7, description="Weight for entropy (default: 0.7)")
    w6: float = Field(0.7, description="Weight for prediction error (default: 0.7)")
    lambda_: float = Field(0.6, description="Time dilation strength (default: 0.6)")
    dt_min: float = Field(0.05, description="Minimum integration step (default: 0.05)")
    dt_max: float = Field(0.5, description="Maximum integration step (default: 0.5)")

class InputVectorRequest(BaseModel):
    x: List[float] = Field(..., description="Input vector for the current step")
    apply_guardian: bool = Field(True, description="Apply guardian processing")

class PsiOutput(BaseModel):
    Psi: float = Field(..., description="Consciousness density")
    C: float = Field(..., description="Coherence")
    U: float = Field(..., description="Understanding")
    Phi: float = Field(..., description="Integration")
    H: float = Field(..., description="Entropy")
    PE: float = Field(..., description="Prediction error")
    M: float = Field(..., description="Memory magnitude")
    dt_eff: float = Field(..., description="Effective integration step")
    k: int = Field(..., description="Step counter")
    timestamp: str = Field(..., description="ISO timestamp")
    _guardian: Optional[Dict[str, Any]] = Field(None, description="Guardian status")

class RememberRecord(BaseModel):
    trace_type: str = Field(..., description="Type of trace (memory, protention)")
    trace_hash: str = Field(..., description="Hash of the trace")
    metadata: Dict[str, Any] = Field(..., description="Metadata for the trace")

# Global variables (additional ones defined in the replaced code above)
psi_engine = None
backend = None
params = None
last_state = None

# Dependency for checking if the Ψ-Field module is imported correctly
def verify_psi_field():
    if not IMPORT_SUCCESS:
        raise HTTPException(status_code=500, detail="Ψ-Field module not available")
    return True

# Initialize the Ψ-Field engine
def initialize_engine(params_dict: Dict[str, Any]):
    global psi_engine, backend, params
    
    # Convert the dictionary to a Params object
    p = psi_core.Params(
        dt=params_dict.get("dt", 0.2),
        W_r=params_dict.get("W_r", 3.0),
        H=params_dict.get("H", 2.0),
        N=params_dict.get("N", 8),
        C_w=params_dict.get("C_w", 32),
        latent_dim=params_dict.get("latent_dim", 32),
        w=(
            params_dict.get("w1", 1.0),
            params_dict.get("w2", 0.8),
            params_dict.get("w3", 0.6),
            params_dict.get("w4", 0.6),
            params_dict.get("w5", 0.7),
            params_dict.get("w6", 0.7),
        ),
        lambda_=params_dict.get("lambda_", 0.6),
        dt_min=params_dict.get("dt_min", 0.05),
        dt_max=params_dict.get("dt_max", 0.5),
    )
    
    # Create backend and engine
    backend = BackendClass(input_dim=params_dict.get("input_dim", 16), 
                           latent_dim=params_dict.get("latent_dim", 32))
    psi_engine = PsiEngine(backend, p)
    params = p
    
    logger.info(f"Initialized Ψ-Field engine with params: {params_dict}")
    return psi_engine

# Function to record to Remembrancer
def record_to_remembrancer(trace_type: str, trace_hash: str, metadata: Dict[str, Any]):
    try:
        cmd = [
            "./ops/bin/remembrancer", "record", trace_type,
            "--component", "psi-field",
            "--version", "v1.0",
            "--sha256", trace_hash,
            "--evidence", json.dumps(metadata)
        ]
        
        # Execute the command
        result = subprocess.run(
            cmd, 
            capture_output=True, 
            text=True, 
            check=True,
            cwd=os.path.join(os.path.dirname(__file__), '..', '..')  # Go up to vm-spawn root
        )
        
        logger.info(f"Recorded to Remembrancer: {trace_type}, {trace_hash[:8]}...")
        return {"success": True, "output": result.stdout}
    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to record to Remembrancer: {e.stderr}")
        return {"success": False, "error": e.stderr}



@app.get("/", tags=["Root"])
async def read_root():
    return {
        "name": "VaultMesh Ψ-Field API",
        "version": "1.0.0",
        "status": "active",
        "timestamp": time.time()
    }

@app.get("/health", tags=["Health"])
async def health_check():
    return {
        "status": "healthy",
        "import_success": IMPORT_SUCCESS,
        "engine_initialized": psi_engine is not None,
        "timestamp": time.time()
    }

@app.post("/init", tags=["Ψ-Field"])
async def initialize(params: PsiParams, _: bool = Depends(verify_psi_field)):
    """Initialize the Ψ-Field engine with custom parameters"""
    params_dict = params.dict()
    initialize_engine(params_dict)
    return {
        "status": "initialized",
        "params": params_dict,
        "timestamp": time.time()
    }

@app.get("/params", tags=["Ψ-Field"])
async def get_parameters(_: bool = Depends(verify_psi_field)):
    """Get the current Ψ-Field parameters"""
    if not psi_engine:
        raise HTTPException(status_code=400, detail="Ψ-Field engine not initialized")
    
    p = psi_engine.params
    return {
        "dt": p.dt,
        "W_r": p.W_r,
        "H": p.H,
        "N": p.N,
        "C_w": p.C_w,
        "latent_dim": p.latent_dim,
        "w1": p.w1,
        "w2": p.w2,
        "w3": p.w3,
        "w4": p.w4,
        "w5": p.w5,
        "w6": p.w6,
        "lambda_": p.lambda_,
        "dt_min": p.dt_min,
        "dt_max": p.dt_max,
        "timestamp": time.time()
    }

def get_last_state() -> Dict[str, Any]:
    """Helper function to get the current state"""
    global last_state, psi_engine
    
    if last_state:
        return last_state
    
    if not psi_engine:
        return {
            "Psi": 0.0,
            "C": 0.0,
            "U": 0.0,
            "Phi": 0.0,
            "H": 0.0,
            "PE": 0.0,
            "M": 0.0,
            "dt_eff": 0.0,
            "k": 0,
            "timestamp": datetime.utcnow().isoformat()
        }
    
    return {
        "Psi": getattr(psi_engine, "last_psi", 0.0),
        "C": getattr(psi_engine, "last_metrics", {}).get("C", 0.0),
        "U": getattr(psi_engine, "last_metrics", {}).get("U", 0.0),
        "Phi": getattr(psi_engine, "last_metrics", {}).get("Phi", 0.0),
        "H": getattr(psi_engine, "last_metrics", {}).get("H", 0.0),
        "PE": getattr(psi_engine, "last_metrics", {}).get("PE", 0.0),
        "M": getattr(psi_engine, "last_metrics", {}).get("M", 0.0),
        "dt_eff": getattr(psi_engine, "last_dt_eff", 0.0),
        "k": getattr(psi_engine, "k", 0),
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/state", response_model=PsiOutput, tags=["Ψ-Field"])
async def get_current_state(_: bool = Depends(verify_psi_field)):
    """Get the current state of the Ψ-field"""
    if not psi_engine:
        raise HTTPException(status_code=400, detail="Ψ-Field engine not initialized")
    
    # Get the current state
    state = get_last_state()
    
    return state

@app.post("/step", response_model=PsiOutput, tags=["Ψ-Field"])
async def step(input_data: InputVectorRequest, background_tasks: BackgroundTasks, _: bool = Depends(verify_psi_field)):
    """Execute one Ψ-field evolution step with the given input"""
    global psi_engine, guardian, remembrancer_client, mq_publisher, last_state
    
    if not psi_engine:
        raise HTTPException(status_code=400, detail="Ψ-Field engine not initialized")
    
    try:
        # Convert input to NumPy array
        x = np.array(input_data.x)
        
        # Apply Guardian if requested
        if input_data.apply_guardian and guardian:
            x = guardian.normalize_input(x)
        
        # Execute the step
        rec = psi_engine.step(x)
        
        # Add timestamp and step counter
        timestamp = datetime.utcnow().isoformat()
        rec["timestamp"] = timestamp
        if not hasattr(psi_engine, "k"):
            psi_engine.k = 0
        psi_engine.k += 1
        rec["k"] = psi_engine.k
        
        # Store latest state for reference
        last_state = rec.copy()
        
        # Apply Guardian processing
        if guardian and input_data.apply_guardian:
            rec = guardian.process_state(rec, psi_engine.k)
            
            # Check if Guardian detected a threat and intervention needed
            if rec['_guardian']['intervention']:
                if rec['_guardian']['intervention'] == 'nigredo':
                    guardian.apply_nigredo(psi_engine)
                elif rec['_guardian']['intervention'] == 'albedo':
                    guardian.apply_albedo(psi_engine)
                
                # Publish alert
                if mq_publisher:
                    mq_publisher.publish_guardian_alert({
                        "agent_id": AGENT_ID,
                        "intervention": rec['_guardian']['intervention'],
                        "reason": rec['_guardian']['reason'],
                        "timestamp": timestamp,
                        "manual": False
                    })
        
        # Record to Remembrancer in the background
        if remembrancer_client:
            background_tasks.add_task(
                remembrancer_client.record,
                rec,
                "psi_state"
            )
        
        # Publish telemetry
        if mq_publisher:
            background_tasks.add_task(
                mq_publisher.publish_telemetry,
                {
                    "agent_id": AGENT_ID,
                    "k": rec["k"],
                    "Psi": float(rec["Psi"]),
                    "C": float(rec["C"]),
                    "U": float(rec["U"]),
                    "Phi": float(rec["Phi"]),
                    "H": float(rec["H"]),
                    "PE": float(rec["PE"]),
                    "M": float(rec["M"]),
                    "dt_eff": float(rec["dt_eff"]),
                    "timestamp": timestamp
                }
            )
            
            # Calculate phase for federation
            phase = complex(np.cos(rec["Phi"]), np.sin(rec["Phi"]))
            
            # Publish metrics to federation in the background
            background_tasks.add_task(
                federation.publish_metrics,
                psi_engine.last_metrics,
                rec["Psi"],
                phase
            )
        
        return rec
    except Exception as e:
        logger.error(f"Error in step: {e}")
        raise HTTPException(status_code=500, detail=f"Error executing step: {str(e)}")

@app.post("/record", tags=["Remembrancer"])
async def record_trace(record: RememberRecord, _: bool = Depends(verify_psi_field)):
    """Manually record a trace to the Remembrancer"""
    result = record_to_remembrancer(record.trace_type, record.trace_hash, record.metadata)
    if result["success"]:
        return {"status": "recorded", "trace_hash": record.trace_hash}
    else:
        raise HTTPException(status_code=500, detail=f"Error recording trace: {result['error']}")

@app.get("/metrics", tags=["Monitoring"])
async def metrics(_: bool = Depends(verify_psi_field)):
    """Get Prometheus metrics for the Ψ-Field service"""
    if not psi_engine:
        return {"status": "not_initialized"}
    
    # Return the latest metrics in Prometheus format
    metrics_string = "# HELP psi_consciousness_density Current Psi consciousness density\n"
    metrics_string += "# TYPE psi_consciousness_density gauge\n"
    metrics_string += f'psi_consciousness_density {getattr(psi_engine, "last_psi", 0.0)}\n'
    
    metrics_string += "# HELP psi_time_dilation Current effective time dilation\n"
    metrics_string += "# TYPE psi_time_dilation gauge\n"
    metrics_string += f'psi_time_dilation {getattr(psi_engine, "last_dt_eff", psi_engine.params.dt)}\n'
    
    # Add swarm metrics if available
    swarm_metrics = getattr(federation, "metrics", {})
    for key, value in swarm_metrics.items():
        metrics_string += f"# HELP psi_{key.lower()} Swarm {key} metric\n"
        metrics_string += f"# TYPE psi_{key.lower()} gauge\n"
        metrics_string += f'psi_{key.lower()} {value}\n'
    
    return metrics_string

@app.get("/federation/metrics", tags=["Federation"])
async def get_federation_metrics():
    """Get federation metrics for the Ψ-Field service"""
    if not psi_engine:
        return {"status": "not_initialized"}
    
    # Get the latest metrics
    last_psi = getattr(psi_engine, "last_psi", 0.0)
    last_metrics = getattr(psi_engine, "last_metrics", {})
    
    return {
        "agent_id": federation.agent_id,
        "psi": last_psi,
        "metrics": last_metrics,
        "timestamp": time.time()
    }

@app.post("/federation/swarm", tags=["Federation"])
async def calculate_swarm_metrics(_: bool = Depends(verify_psi_field)):
    """Calculate and return swarm-level metrics"""
    swarm_metrics = await federation.get_swarm_metrics()
    return {
        "swarm_metrics": swarm_metrics,
        "timestamp": time.time()
    }

# ==========================================================
# GUARDIAN ENDPOINTS
# ==========================================================

@app.post("/guardian/nigredo", tags=["Guardian"])
async def apply_nigredo(_: bool = Depends(verify_psi_field)):
    """Apply Nigredo intervention (dissolution of harmful patterns)"""
    global psi_engine, guardian
    
    if not guardian or not psi_engine:
        raise HTTPException(status_code=503, detail="Guardian not initialized")
    
    result = guardian.apply_nigredo(psi_engine)
    
    # Record the intervention to Remembrancer
    if remembrancer_client:
        await remembrancer_client.record({
            "intervention": "nigredo",
            "timestamp": datetime.utcnow().isoformat(),
            "result": result
        }, event_type="guardian_intervention")
    
    # Publish guardian alert
    if mq_publisher:
        mq_publisher.publish_guardian_alert({
            "intervention": "nigredo",
            "timestamp": datetime.utcnow().isoformat(),
            "manual": True
        })
    
    return result

@app.post("/guardian/albedo", tags=["Guardian"])
async def apply_albedo(_: bool = Depends(verify_psi_field)):
    """Apply Albedo intervention (purification)"""
    global psi_engine, guardian
    
    if not guardian or not psi_engine:
        raise HTTPException(status_code=503, detail="Guardian not initialized")
    
    result = guardian.apply_albedo(psi_engine)
    
    # Record the intervention to Remembrancer
    if remembrancer_client:
        await remembrancer_client.record({
            "intervention": "albedo",
            "timestamp": datetime.utcnow().isoformat(),
            "result": result
        }, event_type="guardian_intervention")
    
    # Publish guardian alert
    if mq_publisher:
        mq_publisher.publish_guardian_alert({
            "intervention": "albedo",
            "timestamp": datetime.utcnow().isoformat(),
            "manual": True
        })
    
    return result

@app.get("/guardian/status", tags=["Guardian"])
async def guardian_status(_: bool = Depends(verify_psi_field)):
    """Get guardian threat assessment"""
    global psi_engine, guardian
    
    if not guardian or not psi_engine:
        raise HTTPException(status_code=503, detail="Guardian not initialized")
    
    current_state = get_last_state()
    is_threat, reason = guardian.assess_threat(current_state)
    
    return {
        "red_flag": guardian._red_flag,
        "reason": guardian._red_flag_reason,
        "current_threat": is_threat,
        "current_threat_reason": reason
    }

@app.get("/guardian/statistics", tags=["Guardian"])
async def guardian_statistics():
    """Get guardian statistics"""
    if guardian and hasattr(guardian, "get_statistics"):
        return {"kind": GUARDIAN_KIND, **guardian.get_statistics()}
    return {"kind": GUARDIAN_KIND, "status": "no-stats"}

# ==========================================================
# REMEMBRANCER ENDPOINTS
# ==========================================================

@app.post("/remembrancer/record", tags=["Remembrancer"])
async def record_to_remembrancer(_: bool = Depends(verify_psi_field)):
    """Record current state to Remembrancer"""
    global remembrancer_client
    
    if not remembrancer_client:
        raise HTTPException(status_code=503, detail="Remembrancer client not initialized")
    
    current_state = get_last_state()
    receipt = await remembrancer_client.record(current_state, "psi_state")
    
    return {
        "receipt": receipt,
        "timestamp": datetime.utcnow().isoformat()
    }

# ==========================================================
# MCP ENDPOINT
# ==========================================================

@app.post("/mcp", tags=["MCP"])
async def mcp_endpoint(request: Request):
    """MCP JSON-RPC 2.0 endpoint"""
    global mcp_server
    
    if not mcp_server:
        raise HTTPException(status_code=503, detail="MCP server not initialized")
    
    return await mcp_server.handle_request(request)

# ==========================================================
# STARTUP/SHUTDOWN HANDLERS
# ==========================================================

@app.on_event("startup")
async def startup_event():
    """Initialize components on startup"""
    global psi_engine, guardian, remembrancer_client, mq_publisher, mcp_server
    
    logger.info("🚀 Starting PSI-Field API service")
    
    # Initialize PSI engine
    if IMPORT_SUCCESS:
        initialize_engine({"input_dim": PSI_INPUT_DIM, "latent_dim": PSI_LATENT_DIM})
        logger.info(f"✅ PSI engine initialized with {PSI_BACKEND} backend")
    
    # Initialize Guardian (AdvancedGuardian by default)
    guardian = Guardian(
        psi_low_threshold=0.25,
        pe_high_threshold=2.0,
        h_high_threshold=2.2,
        percentile_threshold=95 if GUARDIAN_KIND == "advanced" else None,
        history_window=200 if GUARDIAN_KIND == "advanced" else None
    )
    logger.info(f"✅ Guardian initialized ({GUARDIAN_KIND})")
    
    # Initialize Remembrancer client
    remembrancer_client = RemembrancerClient()
    logger.info("✅ Remembrancer client initialized")
    
    # Initialize RabbitMQ publisher
    mq_publisher = RabbitMQPublisher(
        agent_id=AGENT_ID,
        rabbit_url=RABBIT_URL,
        exchange=RABBIT_EXCHANGE,
        enabled=RABBIT_ENABLED
    )
    logger.info("✅ RabbitMQ publisher initialized")
    
    # Initialize MCP server
    mcp_server = MCPServer()
    
    # Register MCP tools
    @mcp_server.tool(name="psi_step", description="Execute one cognitive step")
    async def psi_step_tool(x: List[float], guardian: bool = True):
        params = InputVectorRequest(x=x, apply_guardian=guardian)
        bg_tasks = BackgroundTasks()
        return await step(params, bg_tasks)
    
    @mcp_server.tool(name="psi_get_state", description="Get current state")
    async def psi_get_state_tool():
        return await get_current_state()
    
    @mcp_server.tool(name="psi_apply_nigredo", description="Apply Nigredo intervention")
    async def psi_apply_nigredo_tool(reason: str = "manual"):
        return await apply_nigredo()
    
    app.include_router(mcp_server.router)
    logger.info("✅ MCP server initialized")
    
    # Initialize Aurora federation
    await federation.startup()
    logger.info("✅ Federation initialized")
    
    logger.info("🚀 PSI-Field API service started and ready")

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    global mq_publisher
    
    logger.info("🛑 Shutting down PSI-Field API service")
    
    # Close RabbitMQ connection
    if mq_publisher:
        mq_publisher.close()
    
    # Shutdown Aurora federation
    await federation.shutdown()
    
    logger.info("✅ PSI-Field API service shutdown complete")

# If the module is run directly, start the server
if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)