import os
from fastapi.testclient import TestClient

def test_mq_disabled(monkeypatch):
    """Test that service works with MQ disabled"""
    monkeypatch.setenv("RABBIT_ENABLED", "0")
    
    from services.psi_field.src.main import app
    client = TestClient(app)
    
    r = client.post("/step", json={"x": [0.0]*16, "apply_guardian": True})
    assert r.status_code == 200
    assert "Psi" in r.json()
