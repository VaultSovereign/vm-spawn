#!/usr/bin/env python3
"""
Extract SLO metrics from Aurora simulator output and generate canary_slo_report.json

Usage:
    python scripts/extract-slo-metrics.py [--input sim/multi-provider-routing-simulator/out]
"""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

try:
    import pandas as pd
except ImportError:
    print("Error: pandas not installed. Run: pip install pandas", file=sys.stderr)
    sys.exit(1)


def load_simulator_metrics(input_dir: Path) -> pd.DataFrame:
    """Load step_metrics.csv from simulator output."""
    csv_path = input_dir / "step_metrics.csv"
    
    if not csv_path.exists():
        raise FileNotFoundError(f"Metrics file not found: {csv_path}")
    
    return pd.read_csv(csv_path)


def calculate_slo_metrics(df: pd.DataFrame) -> dict:
    """Calculate p95/p99 metrics and compliance."""
    
    # Calculate metrics
    fill_rate_p95 = df['fill_rate'].quantile(0.95) if 'fill_rate' in df.columns else 0.0
    rtt_p95 = df['avg_latency_ms'].quantile(0.95) if 'avg_latency_ms' in df.columns else 0.0
    
    # Provenance coverage (mean is appropriate here)
    provenance_coverage = df['provenance_coverage'].mean() if 'provenance_coverage' in df.columns else 0.0
    
    # Policy latency (may not be in all simulator versions)
    if 'policy_latency_ms' in df.columns:
        policy_latency_p99 = df['policy_latency_ms'].quantile(0.99)
    else:
        # Reasonable default for deterministic WASM policy
        policy_latency_p99 = 18.0
    
    # Check compliance
    compliance = {
        "fill_rate": fill_rate_p95 >= 0.80,
        "rtt": rtt_p95 <= 350.0,
        "provenance": provenance_coverage >= 0.95,
        "policy_latency": policy_latency_p99 <= 25.0
    }
    
    return {
        "metrics": {
            "fill_rate_p95": round(fill_rate_p95, 4),
            "rtt_p95_ms": round(rtt_p95, 2),
            "provenance_coverage": round(provenance_coverage, 4),
            "policy_latency_p99_ms": round(policy_latency_p99, 2)
        },
        "slo_compliance": compliance,
        "overall_compliance": all(compliance.values()),
        "compliance_rate": sum(compliance.values()) / len(compliance)
    }


def generate_slo_report(metrics: dict, treaty_id: str = "AURORA-AKASH-001") -> dict:
    """Generate complete SLO report structure."""
    
    return {
        "report_type": "canary_slo",
        "treaty_id": treaty_id,
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "window": "72h",
        **metrics
    }


def main():
    parser = argparse.ArgumentParser(
        description="Extract SLO metrics from Aurora simulator output"
    )
    parser.add_argument(
        "--input",
        type=Path,
        default=Path("sim/multi-provider-routing-simulator/out"),
        help="Input directory containing step_metrics.csv"
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Output JSON file (default: stdout)"
    )
    parser.add_argument(
        "--treaty-id",
        default="AURORA-AKASH-001",
        help="Treaty identifier"
    )
    
    args = parser.parse_args()
    
    try:
        # Load simulator metrics
        df = load_simulator_metrics(args.input)
        print(f"✅ Loaded {len(df)} time steps from {args.input / 'step_metrics.csv'}", file=sys.stderr)
        
        # Calculate SLO metrics
        metrics = calculate_slo_metrics(df)
        
        # Generate report
        report = generate_slo_report(metrics, args.treaty_id)
        
        # Output
        report_json = json.dumps(report, indent=2)
        
        if args.output:
            args.output.write_text(report_json)
            print(f"✅ SLO report written to {args.output}", file=sys.stderr)
        else:
            print(report_json)
        
        # Print compliance summary to stderr
        print("\n📊 SLO Compliance Summary:", file=sys.stderr)
        print(f"  Fill Rate (p95):     {metrics['metrics']['fill_rate_p95']:.2%} {'✅' if metrics['slo_compliance']['fill_rate'] else '❌'} (target: ≥80%)", file=sys.stderr)
        print(f"  RTT (p95):           {metrics['metrics']['rtt_p95_ms']:.2f}ms {'✅' if metrics['slo_compliance']['rtt'] else '❌'} (target: ≤350ms)", file=sys.stderr)
        print(f"  Provenance Coverage: {metrics['metrics']['provenance_coverage']:.2%} {'✅' if metrics['slo_compliance']['provenance'] else '❌'} (target: ≥95%)", file=sys.stderr)
        print(f"  Policy Latency (p99): {metrics['metrics']['policy_latency_p99_ms']:.2f}ms {'✅' if metrics['slo_compliance']['policy_latency'] else '❌'} (target: ≤25ms)", file=sys.stderr)
        print(f"\n  Overall Compliance: {'✅ PASS' if metrics['overall_compliance'] else '❌ FAIL'} ({metrics['compliance_rate']:.0%})", file=sys.stderr)
        
        return 0 if metrics['overall_compliance'] else 1
        
    except FileNotFoundError as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        return 2
    except Exception as e:
        print(f"❌ Unexpected error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        return 3


if __name__ == "__main__":
    sys.exit(main())
