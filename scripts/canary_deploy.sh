#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

export PATH="${ROOT_DIR}/bin:${PATH}"
export PYTHONPATH="${ROOT_DIR}/ai:${PYTHONPATH:-}"

MODE="${1:-good}" # good | bad

echo "=========================================================="
echo "🚀 Canary Progressive Delivery Pipeline"
echo "=========================================================="
echo "[canary] Target Mode: ${MODE}"

HELM_CMD="bin/helm"
if ! command -v "${HELM_CMD}" &>/dev/null; then
  HELM_CMD="helm"
fi

KUBECTL_CMD="bin/kubectl"
if ! command -v "${KUBECTL_CMD}" &>/dev/null; then
  KUBECTL_CMD="kubectl"
fi

if [[ "${MODE}" == "good" ]]; then
  echo "[canary] Step 1: Deploying Healthy Canary (20% Traffic Split)..."
  if ${KUBECTL_CMD} cluster-info &>/dev/null; then
    ${HELM_CMD} upgrade --install demo-api "${ROOT_DIR}/deploy/helm/demo-api" \
      --namespace demo \
      -f "${ROOT_DIR}/deploy/helm/demo-api/values.yaml" \
      -f "${ROOT_DIR}/deploy/helm/demo-api/values-canary.yaml" \
      --wait --timeout 2m
  else
    echo "[canary] (Cluster simulation mode: Canary v2.0.0 deployed)"
  fi

  echo "[canary] Step 2: Running Smoke & Anomaly Telemetry Checks (20% Traffic)..."
  sleep 1
  # AI Canary Evaluation with healthy metrics: 0% error rate, 38ms latency
  python3 "${ROOT_DIR}/ai/canary_evaluator.py" 0.0 38.0

  echo "[canary] Step 3: Scaling Canary Traffic Split to 50%..."
  if ${KUBECTL_CMD} cluster-info &>/dev/null; then
    ${HELM_CMD} upgrade demo-api "${ROOT_DIR}/deploy/helm/demo-api" \
      --namespace demo \
      -f "${ROOT_DIR}/deploy/helm/demo-api/values.yaml" \
      -f "${ROOT_DIR}/deploy/helm/demo-api/values-canary.yaml" \
      --set canary.weight=50 \
      --wait --timeout 2m
  else
    echo "[canary] (Cluster simulation mode: Canary shifted to 50% weight)"
  fi
  sleep 1
  python3 "${ROOT_DIR}/ai/canary_evaluator.py" 0.0 41.0

  echo "[canary] Step 4: Promoting Canary to 100% Production Stable..."
  if ${KUBECTL_CMD} cluster-info &>/dev/null; then
    ${HELM_CMD} upgrade demo-api "${ROOT_DIR}/deploy/helm/demo-api" \
      --namespace demo \
      --set image.tag=v2.0.0 \
      --set canary.enabled=false \
      --wait --timeout 2m
  fi
  echo "=========================================================="
  echo "🎉 Release successful! Progressive rollout complete: 20% -> 50% -> 100%."
  echo "=========================================================="

elif [[ "${MODE}" == "bad" ]]; then
  echo "[canary] Step 1: Deploying Faulty Canary (v2.0.0-broken with 500 error injection)..."
  if ${KUBECTL_CMD} cluster-info &>/dev/null; then
    ${HELM_CMD} upgrade --install demo-api "${ROOT_DIR}/deploy/helm/demo-api" \
      --namespace demo \
      -f "${ROOT_DIR}/deploy/helm/demo-api/values.yaml" \
      -f "${ROOT_DIR}/deploy/helm/demo-api/values-canary-broken.yaml" \
      --wait --timeout 2m || true
  else
    echo "[canary] (Cluster simulation mode: Canary v2.0.0-broken deployed)"
  fi

  echo "[canary] Step 2: Running Smoke & Anomaly Telemetry Checks..."
  sleep 1
  # AI Canary Evaluation with faulty metrics: 65% error rate, 550ms latency
  if ! python3 "${ROOT_DIR}/ai/canary_evaluator.py" 0.65 550.0; then
    echo "🚨 [CD Automation] SLA breached! Aborting rollout and executing Helm rollback..."
    if ${KUBECTL_CMD} cluster-info &>/dev/null; then
      ${HELM_CMD} rollback demo-api --namespace demo || true
    fi
    echo "🛡️  Traffic immediately reverted 100% to stable. Broken pods isolated."
    echo ""
    echo "[*] Triggering Autonomous AIOps Incident Responder for Root Cause Analysis:"
    python3 "${ROOT_DIR}/ai/incident_analyzer.py"
  fi
fi
