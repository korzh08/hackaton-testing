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
echo "🔐 Phase 2: Finalize Secret Rotation (Revoke Previous)"
echo "=========================================================="

TMP_DEC=$(mktemp --suffix=.yaml)
sops -d "${ENC_SECRET}" > "${TMP_DEC}"

python3 -c "
import yaml

with open('${TMP_DEC}', 'r') as f:
    data = yaml.safe_load(f)

if 'stringData' not in data:
    data['stringData'] = {}

data['stringData']['API_TOKEN_PREVIOUS'] = ''

with open('${TMP_DEC}', 'w') as f:
    yaml.dump(data, f, default_flow_style=False)
"

PUBKEY=$(age-keygen -y "${KEY_FILE}")
sops --encrypt --age "${PUBKEY}" --encrypted-regex '^(data|stringData)$' --input-type yaml --output-type yaml "${TMP_DEC}" > "${ENC_SECRET}"
rm -f "${TMP_DEC}"

if kubectl cluster-info &>/dev/null; then
  sops -d "${ENC_SECRET}" | kubectl apply -n demo -f -
  kubectl rollout restart deployment -n demo -l app.kubernetes.io/name=demo-api
  echo "[rotate] Waiting for rollout to complete..."
  kubectl rollout status deployment -n demo -l app.kubernetes.io/name=demo-api --timeout=60s || true
fi

echo "=========================================================="
echo "✅ Previous token revoked. Only the new token is active."
echo "=========================================================="
