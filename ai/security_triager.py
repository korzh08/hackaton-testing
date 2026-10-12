#!/usr/bin/env python3
"""AIOps Security Triager.

Ingests Trivy vulnerability scan reports and performs:
1. Reachability & Exploitability Analysis
2. Noise suppression (filtering non-exploitable CVEs)
3. Automated Patch Generation for Dockerfile & requirements.txt
"""

import os
import sys
from copilot import AIOpsCopilot


def triage_security_report(trivy_report_path: str = None) -> str:
    copilot = AIOpsCopilot()

    context = ""
    if trivy_report_path and os.path.exists(trivy_report_path):
        try:
            with open(trivy_report_path, "r", encoding="utf-8") as f:
                content = f.read()
                context = f"SCAN TARGET FILE: {trivy_report_path}\n{content[:2000]}"
        except Exception as e:
            context = f"Error reading {trivy_report_path}: {e}"

    if not context:
        context = (
            "SCAN TARGET: demo-api:v1.0.0\n"
            "VULNERABILITIES:\n"
            "- Total: 4 (CRITICAL: 0, HIGH: 1, MEDIUM: 2, LOW: 1)\n"
            "- HIGH CVE-2024-37891: urllib3 proxy-authorization header leak in redirects.\n"
            "  Installed: urllib3 2.0.7, Fixed in: 2.2.2\n"
            "- MEDIUM CVE-2024-24790: Go runtime / standard library (not applicable in Python runner)\n"
        )

    prompt = (
        f"You are a Cloud Security Engineer for MTS Cloud. Triage this vulnerability scan report. "
        f"Identify true positive risks, provide remediation steps, and output a patch:\n\n{context}"
    )

    return copilot.generate(prompt)


def main():
    report_file = sys.argv[1] if len(sys.argv) > 1 else None
    print("=" * 70)
    print("🛡️ MTS Cloud AIOps Security & CVE Triager")
    print("=" * 70)
    if report_file:
        print(f"[*] Ingesting vulnerability scan report from {report_file}...")
    else:
        print("[*] Ingesting vulnerability scan report...")
    report = triage_security_report(report_file)
    print("-" * 70)
    print(report)
    print("-" * 70)
    print("✅ Security triage completed. Patch ready for review.")


if __name__ == "__main__":
    main()
