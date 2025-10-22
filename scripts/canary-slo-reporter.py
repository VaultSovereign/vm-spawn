#!/usr/bin/env python3
"""
Aurora Canary SLO Reporter
Extracts 72-hour SLO metrics from Prometheus and generates signed report for governance review.

Usage:
    python3 scripts/canary-slo-reporter.py [--prometheus URL] [--treaty-id ID] [--key KEY_ID]

Example:
    python3 scripts/canary-slo-reporter.py --prometheus http://localhost:9090 --treaty-id AURORA-AKASH-001
"""

import argparse
import datetime
import json
import subprocess
import sys
from typing import Optional

try:
    import requests
except ImportError:
    print("Error: requests library not found. Install with: pip install requests")
    sys.exit(1)


def query_prometheus(prom_url: str, expr: str) -> Optional[float]:
    """Query Prometheus and return single metric value."""
    try:
        resp = requests.get(f"{prom_url}/api/v1/query", params={"query": expr}, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        
        if data["status"] != "success":
            return None
            
        results = data["data"]["result"]
        if not results:
            return None
            
        return float(results[0]["value"][1])
    except Exception as e:
        print(f"Warning: Failed to query '{expr}': {e}", file=sys.stderr)
        return None


def generate_report(prom_url: str, treaty_id: str) -> dict:
    """Generate SLO report from Prometheus metrics."""
    
    # Query metrics
    fill_rate_p95 = query_prometheus(
        prom_url,
        f'histogram_quantile(0.95, treaty_fill_rate_bucket{{treaty_id="{treaty_id}"}})'
    )
    
    rtt_p95 = query_prometheus(
        prom_url,
        f'histogram_quantile(0.95, treaty_rtt_ms_bucket{{treaty_id="{treaty_id}"}})'
    )
    
    provenance_coverage = query_prometheus(
        prom_url,
        f'treaty_provenance_coverage{{treaty_id="{treaty_id}"}}'
    )
    
    policy_latency_p99 = query_prometheus(
        prom_url,
        f'histogram_quantile(0.99, policy_decision_ms_bucket{{treaty_id="{treaty_id}"}})'
    )
    
    # Build report
    report = {
        "report_type": "canary_slo",
        "treaty_id": treaty_id,
        "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
        "window": "72h",
        "metrics": {
            "fill_rate_p95": fill_rate_p95,
            "rtt_p95_ms": rtt_p95,
            "provenance_coverage": provenance_coverage,
            "policy_latency_p99_ms": policy_latency_p99
        },
        "slo_compliance": {
            "fill_rate": fill_rate_p95 >= 0.80 if fill_rate_p95 else None,
            "rtt": rtt_p95 <= 350 if rtt_p95 else None,
            "provenance": provenance_coverage >= 0.95 if provenance_coverage else None,
            "policy_latency": policy_latency_p99 <= 25 if policy_latency_p99 else None
        }
    }
    
    # Calculate overall compliance
    compliant = [v for v in report["slo_compliance"].values() if v is not None]
    if compliant:
        report["overall_compliance"] = all(compliant)
        report["compliance_rate"] = sum(compliant) / len(compliant)
    else:
        report["overall_compliance"] = None
        report["compliance_rate"] = None
    
    return report


def sign_report(report_path: str, key_id: str) -> bool:
    """Sign report with GPG."""
    try:
        result = subprocess.run(
            ["gpg", "--detach-sign", "--armor", "--local-user", key_id, report_path],
            capture_output=True,
            text=True,
            check=True
        )
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error: GPG signing failed: {e.stderr}", file=sys.stderr)
        return False
    except FileNotFoundError:
        print("Error: gpg command not found. Install GnuPG.", file=sys.stderr)
        return False


def main():
    parser = argparse.ArgumentParser(description="Generate signed Aurora canary SLO report")
    parser.add_argument(
        "--prometheus",
        default="http://localhost:9090",
        help="Prometheus URL (default: http://localhost:9090)"
    )
    parser.add_argument(
        "--treaty-id",
        default="AURORA-AKASH-001",
        help="Treaty ID to query (default: AURORA-AKASH-001)"
    )
    parser.add_argument(
        "--key",
        default="6E4082C6A410F340",
        help="GPG key ID for signing (default: 6E4082C6A410F340)"
    )
    parser.add_argument(
        "--output",
        default="canary_slo_report.json",
        help="Output file path (default: canary_slo_report.json)"
    )
    parser.add_argument(
        "--no-sign",
        action="store_true",
        help="Skip GPG signing"
    )
    
    args = parser.parse_args()
    
    print(f"🜂 Aurora Canary SLO Reporter")
    print(f"   Prometheus: {args.prometheus}")
    print(f"   Treaty ID: {args.treaty_id}")
    print()
    
    # Generate report
    print("Querying Prometheus metrics...")
    report = generate_report(args.prometheus, args.treaty_id)
    
    # Write report
    with open(args.output, "w") as f:
        json.dump(report, f, indent=2)
    
    print(f"✅ Report written to {args.output}")
    print()
    
    # Display summary
    print("📊 SLO Summary:")
    metrics = report["metrics"]
    compliance = report["slo_compliance"]
    
    print(f"   Fill Rate (p95):        {metrics['fill_rate_p95']:.3f} {'✅' if compliance['fill_rate'] else '❌' if compliance['fill_rate'] is False else '⚠️'}")
    print(f"   RTT (p95):              {metrics['rtt_p95_ms']:.1f}ms {'✅' if compliance['rtt'] else '❌' if compliance['rtt'] is False else '⚠️'}")
    print(f"   Provenance Coverage:    {metrics['provenance_coverage']:.3f} {'✅' if compliance['provenance'] else '❌' if compliance['provenance'] is False else '⚠️'}")
    print(f"   Policy Latency (p99):   {metrics['policy_latency_p99_ms']:.1f}ms {'✅' if compliance['policy_latency'] else '❌' if compliance['policy_latency'] is False else '⚠️'}")
    print()
    
    if report["overall_compliance"] is not None:
        if report["overall_compliance"]:
            print(f"✅ Overall: COMPLIANT ({report['compliance_rate']:.0%})")
        else:
            print(f"❌ Overall: NON-COMPLIANT ({report['compliance_rate']:.0%})")
    else:
        print("⚠️  Overall: INSUFFICIENT DATA")
    print()
    
    # Sign report
    if not args.no_sign:
        print(f"Signing report with key {args.key}...")
        if sign_report(args.output, args.key):
            print(f"✅ Signature written to {args.output}.asc")
            print()
            print("Verify with:")
            print(f"   gpg --verify {args.output}.asc {args.output}")
        else:
            print("⚠️  Signing failed (report still saved)")
            return 1
    
    print()
    print("🜂 Report complete. Attach to governance review.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
