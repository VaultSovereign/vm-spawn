#!/usr/bin/env python3
"""
VaultMesh Simulator Metrics Exporter
Exposes latest simulator run metrics in Prometheus format.
"""

from http.server import BaseHTTPRequestHandler, HTTPServer
import csv
import os
import sys

BASE = "sim/multi-provider-routing-simulator/out"
STEP_CSV = os.path.join(BASE, "step_metrics.csv")
PROVIDER_CSV = os.path.join(BASE, "provider_metrics_over_time.csv")


def latest_step_metrics():
    """Read the last row from step_metrics.csv."""
    if not os.path.exists(STEP_CSV):
        return None
    last = None
    with open(STEP_CSV) as f:
        r = csv.DictReader(f)
        for row in r:
            last = row
    return last


def latest_provider_metrics():
    """Read the last snapshot for each provider from provider_metrics_over_time.csv."""
    if not os.path.exists(PROVIDER_CSV):
        return []
    providers = {}
    with open(PROVIDER_CSV) as f:
        r = csv.DictReader(f)
        for row in r:
            # Keep only the latest step for each provider
            providers[row["provider_id"]] = row
    return list(providers.values())


class MetricsHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        """Suppress default HTTP logging."""
        pass

    def do_GET(self):
        if self.path != "/metrics":
            self.send_response(404)
            self.end_headers()
            return

        step_metrics = latest_step_metrics()
        provider_metrics = latest_provider_metrics()

        if not step_metrics:
            body = "# no simulator metrics available yet\n"
        else:
            # Step-level aggregate metrics
            body = f"""# HELP treaty_fill_rate Fill rate for simulator aggregate
# TYPE treaty_fill_rate gauge
treaty_fill_rate{{treaty_id="SIM-AGG"}} {step_metrics["fill_rate"]}

# HELP treaty_rtt_ms Average latency in milliseconds
# TYPE treaty_rtt_ms gauge
treaty_rtt_ms{{treaty_id="SIM-AGG"}} {step_metrics["avg_latency_ms"]}

# HELP gpu_hours_total Total GPU hours (credits burned)
# TYPE gpu_hours_total counter
gpu_hours_total{{treaty_id="SIM-AGG"}} {step_metrics["credits_burned"]}

# HELP sim_requests_total Total requests in last step
# TYPE sim_requests_total gauge
sim_requests_total{{treaty_id="SIM-AGG"}} {step_metrics["total_requests"]}

# HELP sim_requests_routed Routed requests in last step
# TYPE sim_requests_routed gauge
sim_requests_routed{{treaty_id="SIM-AGG"}} {step_metrics["routed"]}

# HELP sim_requests_dropped Dropped requests in last step
# TYPE sim_requests_dropped gauge
sim_requests_dropped{{treaty_id="SIM-AGG"}} {step_metrics["dropped"]}

# HELP sim_avg_cost_usd Average cost per request in USD
# TYPE sim_avg_cost_usd gauge
sim_avg_cost_usd{{treaty_id="SIM-AGG"}} {step_metrics["avg_cost_usd_per_request"]}

# HELP sim_step Current simulation step
# TYPE sim_step gauge
sim_step{{treaty_id="SIM-AGG"}} {step_metrics["step"]}
"""

            # Provider-level metrics
            if provider_metrics:
                body += "\n# HELP provider_active Provider active status (1=active, 0=inactive)\n"
                body += "# TYPE provider_active gauge\n"
                for pm in provider_metrics:
                    body += f'provider_active{{provider_id="{pm["provider_id"]}"}} {pm["active"]}\n'

                body += "\n# HELP provider_capacity_gpu_hours Provider effective capacity in GPU hours\n"
                body += "# TYPE provider_capacity_gpu_hours gauge\n"
                for pm in provider_metrics:
                    body += f'provider_capacity_gpu_hours{{provider_id="{pm["provider_id"]}"}} {pm["effective_capacity"]}\n'

                body += "\n# HELP provider_latency_ms Provider effective latency in milliseconds\n"
                body += "# TYPE provider_latency_ms gauge\n"
                for pm in provider_metrics:
                    body += f'provider_latency_ms{{provider_id="{pm["provider_id"]}"}} {pm["latency_ms"]}\n'

                body += "\n# HELP provider_price_a100_usd Provider A100 price in USD per hour\n"
                body += "# TYPE provider_price_a100_usd gauge\n"
                for pm in provider_metrics:
                    body += f'provider_price_a100_usd{{provider_id="{pm["provider_id"]}"}} {pm["price_A100"]}\n'

                body += "\n# HELP provider_reputation Provider reputation score (0-100)\n"
                body += "# TYPE provider_reputation gauge\n"
                for pm in provider_metrics:
                    body += f'provider_reputation{{provider_id="{pm["provider_id"]}"}} {pm["reputation"]}\n'

        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4")
        self.end_headers()
        self.wfile.write(body.encode())


def main():
    port = int(os.environ.get("PORT", "9110"))
    server = HTTPServer(("0.0.0.0", port), MetricsHandler)
    print(f"[sim-metrics-exporter] listening on http://0.0.0.0:{port}/metrics")
    print(f"[sim-metrics-exporter] reading from {os.path.abspath(BASE)}")

    if not os.path.exists(STEP_CSV):
        print(f"[warning] {STEP_CSV} not found. Run 'make sim-run' first.")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[sim-metrics-exporter] shutting down")
        server.shutdown()


if __name__ == "__main__":
    main()
