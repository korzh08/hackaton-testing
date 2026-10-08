#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

export PATH="${ROOT_DIR}/bin:${PATH}"

echo "=========================================================="
echo "🧹 Tearing down demo environment..."
echo "=========================================================="

if command -v helm &>/dev/null && kubectl cluster-info &>/dev/null; then
  echo "[down] Uninstalling Helm releases..."
  helm uninstall demo-api --namespace demo || true
fi

echo "[down] Cleaning up temporary rendered files in .state/..."
rm -f "${ROOT_DIR}/.state/rendered-manifests.yaml"

echo "✅ Environment teardown completed."
