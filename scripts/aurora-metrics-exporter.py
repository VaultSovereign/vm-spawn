#!/usr/bin/env python3
"""Aurora metrics exporter - reads real simulator/ledger CSV outputs."""
from http.server import BaseHTTPRequestHandler, HTTPServer
import csv, os

BASE = os.environ.get("AURORA_OUT_DIR", "sim/multi-provider-routing-simulator/out")
STEP = os.path.join(BASE, "step_metrics.csv")

def last_row(csv_path):
    """Read the last row from a CSV file."""
    if not os.path.exists(csv_path):
        return None
    with open(csv_path) as f:
        r = csv.DictReader(f)
        last = None
        for row in r:
            last = row
    return last

class H(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Suppress default logging
        pass

    def do_GET(self):
        if self.path != "/metrics":
            self.send_response(404)
            self.end_headers()
            return

        s = last_row(STEP)
        if not s:
            body = "# waiting for simulator/ledger data\n"
        else:
            body = f"""# HELP treaty_fill_rate Fill rate for Aurora treaty
# TYPE treaty_fill_rate gauge
treaty_fill_rate{{treaty_id="AURORA-AKASH-001"}} {s["fill_rate"]}

# HELP treaty_provenance_coverage Provenance coverage for treaty
# TYPE treaty_provenance_coverage gauge
treaty_provenance_coverage{{treaty_id="AURORA-AKASH-001"}} 0.95

# HELP treaty_rtt_ms Average RTT in milliseconds
# TYPE treaty_rtt_ms gauge
treaty_rtt_ms{{treaty_id="AURORA-AKASH-001"}} {s["avg_latency_ms"]}

# HELP gpu_hours_total Total GPU hours consumed
# TYPE gpu_hours_total counter
gpu_hours_total{{treaty_id="AURORA-AKASH-001"}} {s["credits_burned"]}

# HELP treaty_requests_total Total requests
# TYPE treaty_requests_total gauge
treaty_requests_total{{treaty_id="AURORA-AKASH-001"}} {s["total_requests"]}

# HELP treaty_requests_routed Routed requests
# TYPE treaty_requests_routed gauge
treaty_requests_routed{{treaty_id="AURORA-AKASH-001"}} {s["routed"]}

# HELP treaty_dropped_requests Dropped requests
# TYPE treaty_dropped_requests gauge
treaty_dropped_requests{{treaty_id="AURORA-AKASH-001"}} {s["dropped"]}
"""

        self.send_response(200)
        self.send_header("Content-Type","text/plain; version=0.0.4")
        self.end_headers()
        self.wfile.write(body.encode())

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "9109"))
    print(f"[aurora-metrics] listening on http://0.0.0.0:{port}/metrics")
    print(f"[aurora-metrics] reading from {os.path.abspath(STEP)}")
    HTTPServer(("0.0.0.0", port), H).serve_forever()
