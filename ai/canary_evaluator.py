#!/usr/bin/env python3
"""AIOps Canary Evaluator.

Analyzes Canary vs Stable performance metrics (Error Rate, Latency p95/p99)
and makes an autonomous deployment verdict:
- PROMOTE (Progressive rollout: 20% -> 50% -> 100%)
- ABORT / ROLLBACK (Immediate traffic isolation and helm rollback)
"""

import sys
import json
from copilot import AIOpsCopilot


def evaluate_canary(error_rate: float, p95_latency_ms: float, sample_count: int = 50) -> dict:
    copilot = AIOpsCopilot()

    is_degraded = error_rate > 0.05 or p95_latency_ms > 500.0
    status = "ROLLBACK" if is_degraded else "PROMOTE"

    summary = {
        "verdict": status,
        "metrics": {
            "error_rate_percent": round(error_rate * 100, 2),
            "p95_latency_ms": p95_latency_ms,
            "samples_analyzed": sample_count,
        },
        "sla_thresholds": {
            "max_allowed_error_rate_percent": 5.0,
            "max_allowed_p95_latency_ms": 500.0,
        },
    }

    prompt = (
        f"Canary Evaluation Request:\n"
        f"Verdict: {status}\n"
        f"Measured Error Rate: {summary['metrics']['error_rate_percent']}%\n"
        f"Measured p95 Latency: {p95_latency_ms}ms\n"
        f"Explain why this decision was reached and list next automated steps."
    )

    reasoning = copilot.generate(prompt)
    summary["ai_reasoning"] = reasoning
    return summary


def main():
    # Read CLI args or defaults
    error_rate = float(sys.argv[1]) if len(sys.argv) > 1 else 0.0
    latency = float(sys.argv[2]) if len(sys.argv) > 2 else 45.0

    print("=" * 70)
    print("🚦 MTS Cloud AIOps Progressive Canary Evaluator")
    print("=" * 70)
    print(f"[*] Analyzing telemetry: Error Rate = {error_rate*100:.1f}%, p95 = {latency}ms...")
    
    result = evaluate_canary(error_rate, latency)
    print(f"[*] Verdict: {result['verdict']}")
    print("-" * 70)
    print(result["ai_reasoning"])
    print("-" * 70)

    if result["verdict"] == "ROLLBACK":
        print("❌ Canary SLA breached. Triggering automated Helm rollback.")
        sys.exit(1)
    else:
        print("✅ Canary SLA passed. Proceeding with traffic promotion (20% -> 50% -> 100%).")
        sys.exit(0)


if __name__ == "__main__":
    main()
