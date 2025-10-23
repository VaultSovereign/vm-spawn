# 🚀 Hugging Face Spaces Deployment Plan — VaultMesh Infrastructure

**Date:** 2025-10-23  
**Target:** Hugging Face Spaces (mrkarol/code-space)  
**Status:** READY TO EXECUTE

---

## 🎯 Deployment Strategy

### Overview
Deploy VaultMesh PSI-Field and core infrastructure to Hugging Face Spaces for:
- **Live Demo**: Public-facing consciousness density control system
- **API Access**: REST API for PSI-Field operations
- **Interactive UI**: Gradio/Streamlit interface for visualization
- **Documentation**: Live documentation with examples

### Architecture Choice: Gradio App + FastAPI Backend

Hugging Face Spaces works best with:
1. **Gradio** (recommended) - Interactive UI with built-in API
2. **Streamlit** - Dashboard-style interface
3. **Docker** - Full control (requires paid tier)

**Recommendation:** Use Gradio with embedded FastAPI backend

---

## 📦 What to Deploy

### Phase 1: Core PSI-Field Service (Priority 1)
**Files:**
- `services/psi-field/src/` - Core PSI engine
- `vaultmesh_psi/` - PSI algorithm implementation
- `services/psi-field/requirements.txt` - Dependencies

**Deliverables:**
- Interactive Gradio UI for PSI control
- REST API endpoints
- Real-time metrics visualization
- Health monitoring dashboard

### Phase 2: Scheduler Service (Priority 2)
**Files:**
- `services/scheduler/src/` - Cadence manager
- `services/scheduler/config/` - Configuration

**Deliverables:**
- Task scheduling interface
- SLO tracking dashboard
- Prometheus metrics

### Phase 3: Documentation Hub (Priority 3)
**Files:**
- `docs/PSI_FIELD.md` - PSI documentation
- `README.md` - Main documentation
- `AGENTS.md` - Architecture guide
- `START_HERE.md` - Quick start

**Deliverables:**
- Interactive documentation
- Code examples
- Live API playground

---

## 🏗️ Implementation Plan

### Step 1: Create Hugging Face Space Structure (15 min)

```bash
# Create HF Space directory structure
mkdir -p hf-space/{src,static,examples}

# Copy core files
cp -r services/psi-field/src hf-space/src/psi
cp -r vaultmesh_psi hf-space/src/
cp services/psi-field/requirements.txt hf-space/
```

### Step 2: Create Gradio Interface (30 min)

Create `hf-space/app.py`:

```python
import gradio as gr
import numpy as np
from src.psi.main import initialize_engine
import plotly.graph_objects as go

# Initialize PSI engine
engine = None
state_history = []

def initialize_psi(dt, latent_dim):
    """Initialize PSI-Field engine"""
    global engine
    params = {
        "dt": dt,
        "latent_dim": latent_dim,
        "input_dim": 16
    }
    engine = initialize_engine(params)
    return "✅ PSI-Field Engine Initialized"

def step_psi(input_vector):
    """Execute one PSI step"""
    global engine, state_history
    
    if engine is None:
        return "❌ Initialize engine first", None
    
    # Convert input to numpy array
    x = np.array(input_vector.split(','), dtype=float)
    
    # Execute step
    rec = engine.step(x)
    state_history.append(rec)
    
    # Create visualization
    fig = create_psi_plot(state_history)
    
    return f"""
    **Step {rec['k']}**
    - Ψ (Consciousness): {rec['Psi']:.4f}
    - C (Continuity): {rec['C']:.4f}
    - U (Futurity): {rec['U']:.4f}
    - H (Entropy): {rec['H']:.4f}
    - PE (Prediction Error): {rec['PE']:.4f}
    """, fig

def create_psi_plot(history):
    """Create Plotly visualization"""
    if not history:
        return None
    
    steps = [h['k'] for h in history]
    psi = [h['Psi'] for h in history]
    pe = [h['PE'] for h in history]
    
    fig = go.Figure()
    fig.add_trace(go.Scatter(x=steps, y=psi, name='Ψ (Consciousness)', line=dict(color='blue')))
    fig.add_trace(go.Scatter(x=steps, y=pe, name='PE (Error)', line=dict(color='red')))
    
    fig.update_layout(
        title="PSI-Field Evolution",
        xaxis_title="Step",
        yaxis_title="Value",
        template="plotly_dark"
    )
    
    return fig

# Gradio Interface
with gr.Blocks(theme=gr.themes.Soft(), title="VaultMesh PSI-Field") as demo:
    gr.Markdown("""
    # 🜂 VaultMesh PSI-Field Control System
    
    **Consciousness Density Control through Memory-Time Dynamics**
    
    The PSI-Field Evolution Algorithm treats consciousness (Ψ) as emergent from:
    - **Continuity (C)**: Binding present to past
    - **Futurity (U)**: Anticipatory grip on near futures
    - **Phase Coherence (Φ)**: Temporal alignment
    - **Entropy (H)**: Uncertainty across retention→prediction
    - **Prediction Error (PE)**: Mismatch between expected and realized
    """)
    
    with gr.Tab("Initialize"):
        with gr.Row():
            dt_input = gr.Slider(0.05, 0.5, value=0.2, label="Time Step (dt)")
            latent_dim = gr.Slider(8, 64, value=32, step=8, label="Latent Dimension")
        
        init_button = gr.Button("🚀 Initialize Engine", variant="primary")
        init_output = gr.Textbox(label="Status")
        
        init_button.click(
            fn=initialize_psi,
            inputs=[dt_input, latent_dim],
            outputs=init_output
        )
    
    with gr.Tab("Control"):
        gr.Markdown("### Execute PSI Step")
        
        input_vector = gr.Textbox(
            label="Input Vector (16 comma-separated values)",
            value="0.5,0.3,0.1,0.2,0.4,0.6,0.2,0.1,0.3,0.5,0.4,0.2,0.1,0.3,0.5,0.2"
        )
        
        step_button = gr.Button("⚡ Execute Step", variant="primary")
        
        with gr.Row():
            state_output = gr.Markdown(label="Current State")
            plot_output = gr.Plot(label="PSI Evolution")
        
        step_button.click(
            fn=step_psi,
            inputs=input_vector,
            outputs=[state_output, plot_output]
        )
    
    with gr.Tab("API"):
        gr.Markdown("""
        ### REST API Endpoints
        
        ```bash
        # Initialize
        POST /init
        {"dt": 0.2, "latent_dim": 32}
        
        # Execute step
        POST /step
        {"x": [0.5, 0.3, ...], "apply_guardian": true}
        
        # Get state
        GET /state
        
        # Health check
        GET /health
        ```
        """)
    
    with gr.Tab("Documentation"):
        gr.Markdown("""
        ### Quick Start
        
        1. **Initialize** the PSI engine with desired parameters
        2. **Execute steps** by providing input vectors
        3. **Monitor** consciousness density (Ψ) and prediction error (PE)
        4. **Observe** how the system adapts over time
        
        ### Core Metrics
        
        - **Ψ (Psi)**: Consciousness density [0, 1]
        - **C (Continuity)**: Memory coherence
        - **U (Futurity)**: Prediction strength
        - **Φ (Phase)**: Temporal alignment
        - **H (Entropy)**: System uncertainty
        - **PE (Prediction Error)**: Learning signal
        
        ### Advanced Features
        
        - **Guardian**: Automatic threat detection & intervention
        - **Backends**: Simple, Kalman, Seasonal predictors
        - **Federation**: Multi-agent swarm coordination
        - **Remembrancer**: Cryptographic memory recording
        
        ### Links
        
        - [GitHub](https://github.com/VaultSovereign/vm-spawn)
        - [Documentation](https://github.com/VaultSovereign/vm-spawn/blob/main/docs/PSI_FIELD.md)
        - [Architecture](https://github.com/VaultSovereign/vm-spawn/blob/main/AGENTS.md)
        """)

demo.launch()
```

### Step 3: Create Requirements File (5 min)

Create `hf-space/requirements.txt`:

```txt
gradio>=4.0.0
fastapi==0.97.0
uvicorn==0.22.0
numpy==1.24.3
pydantic==1.10.9
plotly>=5.17.0
prometheus-client==0.17.0
```

### Step 4: Create README for HF Space (10 min)

Create `hf-space/README.md`:

```markdown
---
title: VaultMesh PSI-Field
emoji: 🜂
colorFrom: blue
colorTo: purple
sdk: gradio
sdk_version: 4.0.0
app_file: app.py
pinned: false
license: mit
---

# 🜂 VaultMesh PSI-Field Control System

**Consciousness Density Control through Memory-Time Dynamics**

## What is PSI-Field?

The Ψ-Field Evolution Algorithm is a consciousness density control system that treats Ψ as emergent from:
- Memory-time dynamics
- Prediction and futurity
- Phase coherence

## Features

- 🧠 **Real-time PSI Control**: Interactive consciousness density management
- 📊 **Live Metrics**: Visualize Ψ, PE, H, C, U, Φ in real-time
- 🛡️ **Guardian System**: Automatic threat detection (Nigredo/Albedo)
- 🔮 **Multiple Backends**: Simple, Kalman, Seasonal predictors
- 🌐 **REST API**: Full API access for integration

## Quick Start

1. **Initialize** the engine with parameters
2. **Execute steps** with input vectors
3. **Monitor** consciousness density evolution
4. **Experiment** with different backends

## Architecture

Part of the VaultMesh sovereign infrastructure:
- Layer 1: Spawn Elite (infrastructure forge)
- Layer 2: The Remembrancer (cryptographic memory)
- Layer 3: Aurora (distributed coordination)

## Links

- [GitHub Repository](https://github.com/VaultSovereign/vm-spawn)
- [Documentation](https://github.com/VaultSovereign/vm-spawn/blob/main/docs/PSI_FIELD.md)
- [Architecture Guide](https://github.com/VaultSovereign/vm-spawn/blob/main/AGENTS.md)

---

**Astra inclinant, sed non obligant. 🜂**
```

### Step 5: Deploy to Hugging Face (10 min)

```bash
# Copy all files to HF Space structure
cd /home/sovereign/vm-spawn

# Create deployment directory
mkdir -p hf-deploy
cd hf-deploy

# Copy PSI core
cp -r ../services/psi-field/src .
cp -r ../vaultmesh_psi .

# Create app.py (from template above)
# Create requirements.txt (from template above)
# Create README.md (from template above)

# Initialize git and push
git init
git remote add origin https://mrkarol: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@huggingface.co/spaces/mrkarol/code-space
git add .
git commit -m "feat: Deploy VaultMesh PSI-Field to Hugging Face Spaces"
git push -u origin main
```

---

## 🎨 Alternative: Streamlit Dashboard

If you prefer a dashboard-style interface:

```python
import streamlit as st
import numpy as np
import plotly.graph_objects as go
from src.psi.main import initialize_engine

st.set_page_config(
    page_title="VaultMesh PSI-Field",
    page_icon="🜂",
    layout="wide"
)

st.title("🜂 VaultMesh PSI-Field Control System")

# Sidebar controls
with st.sidebar:
    st.header("Engine Configuration")
    dt = st.slider("Time Step (dt)", 0.05, 0.5, 0.2)
    latent_dim = st.slider("Latent Dimension", 8, 64, 32, step=8)
    
    if st.button("Initialize Engine"):
        st.session_state.engine = initialize_engine({
            "dt": dt,
            "latent_dim": latent_dim,
            "input_dim": 16
        })
        st.success("Engine initialized!")

# Main area
col1, col2 = st.columns([2, 1])

with col1:
    st.subheader("PSI Evolution")
    # Plot PSI metrics over time
    
with col2:
    st.subheader("Current State")
    # Display current Ψ, PE, H, C, U, Φ
```

---

## 📋 Deployment Checklist

### Pre-Deployment
- [ ] Test PSI-Field locally
- [ ] Verify all dependencies install correctly
- [ ] Create example input vectors
- [ ] Prepare documentation
- [ ] Test Gradio interface locally

### Deployment
- [ ] Create HF Space directory structure
- [ ] Copy PSI-Field source code
- [ ] Create app.py (Gradio interface)
- [ ] Create requirements.txt
- [ ] Create README.md with HF metadata
- [ ] Test locally with `gradio app.py`
- [ ] Push to Hugging Face repository

### Post-Deployment
- [ ] Verify Space builds successfully
- [ ] Test all interface tabs
- [ ] Verify API endpoints work
- [ ] Test with various input vectors
- [ ] Monitor Space logs for errors
- [ ] Update GitHub with HF Space link

---

## 🎯 Success Criteria

### Gradio Space
- [ ] Space builds without errors
- [ ] PSI engine initializes correctly
- [ ] Step execution works
- [ ] Plots render correctly
- [ ] API is accessible
- [ ] Documentation is readable

### Performance
- [ ] Cold start < 30 seconds
- [ ] Step execution < 1 second
- [ ] Plot updates smoothly
- [ ] No memory leaks over 100 steps

### User Experience
- [ ] Clear instructions
- [ ] Example inputs provided
- [ ] Error messages helpful
- [ ] Metrics easy to understand
- [ ] Links to docs work

---

## 🚀 Quick Deploy Script

```bash
#!/bin/bash
# Quick deploy script for HF Spaces

set -e

echo "🚀 Deploying VaultMesh PSI-Field to Hugging Face..."

# Create deployment directory
rm -rf hf-deploy
mkdir -p hf-deploy/src
cd hf-deploy

# Copy core files
cp -r ../services/psi-field/src/backends src/
cp -r ../services/psi-field/src/guardian*.py src/
cp -r ../services/psi-field/src/mcp.py src/
cp -r ../vaultmesh_psi .

# Copy simplified main (remove RabbitMQ, Remembrancer for HF)
cat > src/psi_engine.py << 'EOF'
"""Simplified PSI engine for Hugging Face Spaces"""
import numpy as np
from vaultmesh_psi.vaultmesh_psi.psi_core import Params, PsiEngine
from vaultmesh_psi.vaultmesh_psi.backends.simple import SimpleBackend

def initialize_engine(config):
    params = Params(
        dt=config.get("dt", 0.2),
        W_r=config.get("W_r", 3.0),
        H=config.get("H", 2.0),
        N=config.get("N", 8),
        C_w=config.get("C_w", 32),
        latent_dim=config.get("latent_dim", 32),
        w=(1.0, 0.8, 0.6, 0.6, 0.7, 0.7),
        lambda_=0.6,
        dt_min=0.05,
        dt_max=0.5
    )
    
    backend = SimpleBackend(
        input_dim=config.get("input_dim", 16),
        latent_dim=config.get("latent_dim", 32)
    )
    
    return PsiEngine(backend, params)
EOF

# Create Gradio app
cat > app.py << 'EOF'
# [Insert Gradio app code from Step 2]
EOF

# Create requirements
cat > requirements.txt << 'EOF'
gradio>=4.0.0
numpy==1.24.3
plotly>=5.17.0
pydantic==1.10.9
EOF

# Create README
cat > README.md << 'EOF'
# [Insert HF Space README from Step 4]
EOF

# Initialize git
git init
git add .
git commit -m "feat: Initial VaultMesh PSI-Field deployment"

# Add HF remote and push
git remote add origin https://mrkarol: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@huggingface.co/spaces/mrkarol/code-space
git push -u origin main --force

echo "✅ Deployment complete!"
echo "🌐 Check your Space at: https://huggingface.co/spaces/mrkarol/code-space"
```

---

## 🔧 Troubleshooting

### Build Fails
```bash
# Check HF Space logs
# Common issues:
# 1. Missing dependencies in requirements.txt
# 2. Import errors (check file paths)
# 3. Port conflicts (Gradio uses 7860 by default)
```

### App Doesn't Load
```bash
# Verify:
# 1. README.md has correct YAML metadata
# 2. app.py is in root directory
# 3. requirements.txt includes all deps
# 4. No syntax errors in Python code
```

### Slow Performance
```bash
# Optimize:
# 1. Reduce latent_dim default
# 2. Limit history buffer size
# 3. Use smaller plot update intervals
# 4. Consider HF Pro for better hardware
```

---

## 📊 Estimated Timeline

| Phase | Task | Duration |
|-------|------|----------|
| 1 | Create HF Space structure | 15 min |
| 2 | Develop Gradio interface | 30 min |
| 3 | Test locally | 20 min |
| 4 | Create documentation | 15 min |
| 5 | Deploy to HF | 10 min |
| 6 | Verify & test | 15 min |
| **Total** | | **~2 hours** |

---

## 🎉 Next Steps After Deployment

1. **Share the Space**: Post on social media, Reddit, HN
2. **Add Examples**: Create preset scenarios
3. **Enable API**: Document API usage
4. **Create Tutorials**: Video walkthrough
5. **Integrate with GitHub**: Add HF badge to README
6. **Monitor Usage**: Track metrics, improve UX
7. **Gather Feedback**: Iterate based on users

---

**Ready to deploy?**

```bash
# Execute the quick deploy script
chmod +x hf-deploy.sh
./hf-deploy.sh
```

---

**Astra inclinant, sed non obligant. 🜂**
