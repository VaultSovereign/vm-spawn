#!/usr/bin/env python3
"""Axelar-style bridge mock with schema+signature verification."""
import base64, json, os, random, pathlib
from http.server import BaseHTTPRequestHandler, HTTPServer

# Optional schema validation (requires jsonschema)
try:
    from jsonschema import validate, ValidationError
    SCHEMA_PATH = os.environ.get("AURORA_ORDER_SCHEMA", "schemas/axelar-order.schema.json")
    if os.path.exists(SCHEMA_PATH):
        ORDER_SCHEMA = json.loads(pathlib.Path(SCHEMA_PATH).read_text())
        VALIDATE_SCHEMA = True
    else:
        VALIDATE_SCHEMA = False
except ImportError:
    VALIDATE_SCHEMA = False

# Optional signature verification (requires cryptography)
try:
    from cryptography.hazmat.primitives.asymmetric import ed25519
    from cryptography.hazmat.primitives import serialization
    PUBKEY_PATH = os.environ.get("AURORA_PUBKEY", "secrets/vm_httpsig.pub")
    if os.path.exists(PUBKEY_PATH):
        PUBKEY = serialization.load_pem_public_key(pathlib.Path(PUBKEY_PATH).read_bytes())
        VERIFY_SIG = True
    else:
        VERIFY_SIG = False
except ImportError:
    VERIFY_SIG = False

def verify_signature(payload: dict):
    if not VERIFY_SIG:
        return True, "signature verification disabled"
    sig_b64 = payload.get("signature","")
    if not sig_b64: return False, "missing signature"
    try:
        sig = base64.b64decode(sig_b64)
        canon = json.dumps({k:v for k,v in payload.items() if k!="signature"}, separators=(",",":"), sort_keys=True).encode()
        PUBKEY.verify(sig, canon)
        return True, "ok"
    except Exception as e:
        return False, f"bad signature: {e}"

class H(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Suppress default logging or customize
        pass

    def do_POST(self):
        if self.path != "/aurora/order":
            self.send_response(404); self.end_headers(); return

        raw = self.rfile.read(int(self.headers.get("Content-Length","0") or "0"))
        try:
            payload = json.loads(raw or b"{}")
        except json.JSONDecodeError:
            self.send_response(400); self.end_headers()
            self.wfile.write(b'{"error":"invalid json"}')
            return

        # Validate schema if enabled
        if VALIDATE_SCHEMA:
            try:
                validate(payload, ORDER_SCHEMA)
            except ValidationError as e:
                self.send_response(422); self.end_headers()
                self.wfile.write(json.dumps({"error":"schema","detail":str(e.message)}).encode())
                return

        # Verify signature if enabled
        ok, why = verify_signature(payload)
        if not ok:
            self.send_response(401); self.end_headers()
            self.wfile.write(json.dumps({"error":"signature","detail":why}).encode())
            return

        # Return ACK
        resp = {
            "ack_id": f"AKASH-JOB-{random.randint(1000,9999)}",
            "signature": "MOCK_SIG",
            "rtt_ms": random.randint(220,340),
            "received": payload.get("treaty_id", "")
        }
        body = json.dumps(resp, separators=(",",":")).encode()
        self.send_response(200)
        self.send_header("Content-Type","application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

        print(f"[aurora-mock] accepted order treaty_id={payload.get('treaty_id')} tenant_id={payload.get('tenant_id')}")

if __name__ == "__main__":
    print("[aurora-mock] listening on http://0.0.0.0:8080/aurora/order")
    print(f"[aurora-mock] schema validation: {'enabled' if VALIDATE_SCHEMA else 'disabled'}")
    print(f"[aurora-mock] signature verification: {'enabled' if VERIFY_SIG else 'disabled'}")
    HTTPServer(("0.0.0.0", 8080), H).serve_forever()
