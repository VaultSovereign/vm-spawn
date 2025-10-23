import pytest
import sys
import os
from fastapi.testclient import TestClient
import numpy as np

# Add the parent directory to the path so we can import the main module
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Mock the vaultmesh_psi module if it's not available
try:
    from src.main import app
except ImportError:
    # Create mock classes and functions for testing
    import mock
    sys.modules['vaultmesh_psi'] = mock.Mock()
    sys.modules['vaultmesh_psi.vaultmesh_psi'] = mock.Mock()
    sys.modules['vaultmesh_psi.vaultmesh_psi.psi_core'] = mock.Mock()
    sys.modules['vaultmesh_psi.vaultmesh_psi.backends'] = mock.Mock()
    sys.modules['vaultmesh_psi.vaultmesh_psi.backends.simple'] = mock.Mock()
    
    # Now import the app
    from src.main import app

client = TestClient(app)

def test_read_root():
    response = client.get("/")
    assert response.status_code == 200
    assert "name" in response.json()
    assert "version" in response.json()
    assert "status" in response.json()
    assert "timestamp" in response.json()

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert "status" in response.json()
    assert "import_success" in response.json()
    assert "engine_initialized" in response.json()
    assert "timestamp" in response.json()

# Skip the remaining tests if the vaultmesh_psi module is not available
if not hasattr(sys.modules.get('vaultmesh_psi', None), 'vaultmesh_psi'):
    pytest.skip("vaultmesh_psi module not available", allow_module_level=True)
else:
    def test_init_params():
        params = {
            "dt": 0.1,
            "W_r": 2.0,
            "H": 1.5,
            "N": 4,
            "C_w": 16,
            "latent_dim": 16,
            "w1": 0.9,
            "w2": 0.7,
            "w3": 0.5,
            "w4": 0.5,
            "w5": 0.6,
            "w6": 0.6,
            "lambda_": 0.5,
            "dt_min": 0.03,
            "dt_max": 0.4
        }
        
        response = client.post("/init", json=params)
        assert response.status_code == 200
        assert response.json()["status"] == "initialized"
        assert "params" in response.json()
        
        # Check that params were updated
        get_params_response = client.get("/params")
        assert get_params_response.status_code == 200
        for key, value in params.items():
            assert get_params_response.json()[key] == value
    
    def test_step():
        # Initialize first
        client.post("/init", json={"dt": 0.2, "W_r": 3.0, "H": 2.0, "N": 8})
        
        # Execute a step
        input_data = {"x_k": [0.1, 0.2, 0.3, 0.4, 0.5] * 3}
        response = client.post("/step", json=input_data)
        
        assert response.status_code == 200
        assert "Psi" in response.json()
        assert "dt_eff" in response.json()
        assert "metrics" in response.json()
        assert "timestamp" in response.json()
        
        # Check metrics
        metrics = response.json()["metrics"]
        assert "C" in metrics
        assert "U" in metrics
        assert "Phi" in metrics
        assert "H" in metrics
        assert "PE" in metrics