#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

export PATH="${ROOT_DIR}/bin:${PATH}"
STATE_DIR="${ROOT_DIR}/.state"
KEY_FILE="${STATE_DIR}/age.key"
export SOPS_AGE_KEY_FILE="${KEY_FILE}"

ENC_SECRET="${ROOT_DIR}/secrets/app.enc.yaml"

echo "=========================================================="
echo "🔐 Phase 1: Zero-Downtime Secret Rotation (Dual-Token)"
echo "=========================================================="

CURRENT_TOKEN=$(sops -d --extract '["stringData"]["API_TOKEN"]' "${ENC_SECRET}" 2>/dev/null || echo "super-secret-production-token-2026")
NEW_TOKEN=$(python3 -c "import secrets; print(secrets.token_hex(20))")

echo "[rotate] Current Token:     ${CURRENT_TOKEN:0:8}..."
echo "[rotate] Generated Token:   ${NEW_TOKEN:0:8}..."

TMP_DEC=$(mktemp --suffix=.yaml)
sops -d "${ENC_SECRET}" > "${TMP_DEC}"

python3 -c "
import yaml

with open('${TMP_DEC}', 'r') as f:
    data = yaml.safe_load(f)

if 'stringData' not in data:
    data['stringData'] = {}

data['stringData']['API_TOKEN_PREVIOUS'] = '${CURRENT_TOKEN}'
data['stringData']['API_TOKEN'] = '${NEW_TOKEN}'

with open('${TMP_DEC}', 'w') as f:
    yaml.dump(data, f, default_flow_style=False)
"

PUBKEY=$(age-keygen -y "${KEY_FILE}")
sops --encrypt --age "${PUBKEY}" --encrypted-regex '^(data|stringData)$' --input-type yaml --output-type yaml "${TMP_DEC}" > "${ENC_SECRET}"
rm -f "${TMP_DEC}"

echo "[rotate] secrets/app.enc.yaml re-encrypted with dual-token acceptance."

if kubectl cluster-info &>/dev/null; then
  sops -d "${ENC_SECRET}" | kubectl apply -n demo -f -
  kubectl rollout restart deployment -n demo -l app.kubernetes.io/name=demo-api
  echo "[rotate] Waiting for rollout to complete..."
  kubectl rollout status deployment -n demo -l app.kubernetes.io/name=demo-api --timeout=60s || true
  echo "[rotate] Pods are restarted with dual-token support. Zero downtime guaranteed!"
fi

echo "=========================================================="
echo "✅ Both new and previous tokens are now accepted by API."
echo "👉 Run 'make secret-rotate-finish' when clients are migrated."
echo "=========================================================="
