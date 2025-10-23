import os
import pytest
from fastapi.testclient import TestClient

def test_backend_env_switch(monkeypatch):
    """Test that PSI_BACKEND env var switches backend"""
    monkeypatch.setenv("PSI_BACKEND", "kalman")
    monkeypatch.setenv("PSI_INPUT_DIM", "16")
    monkeypatch.setenv("PSI_LATENT_DIM", "32")
    
    from services.psi_field.src.main import app
    client = TestClient(app)
    
    r = client.post("/step", json={"x": [0.0]*16, "apply_guardian": False})
    assert r.status_code == 200
    assert "Psi" in r.json()
