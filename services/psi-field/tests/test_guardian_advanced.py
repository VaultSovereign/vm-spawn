from fastapi.testclient import TestClient
from services.psi_field.src.main import app

def test_guardian_stats_endpoint():
    """Test /guardian/statistics endpoint exists and returns kind"""
    client = TestClient(app)
    resp = client.get("/guardian/statistics")
    assert resp.status_code == 200
    body = resp.json()
    assert "kind" in body
    assert body["kind"] in ["basic", "advanced"]
