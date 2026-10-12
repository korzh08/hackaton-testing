#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

export PATH="${ROOT_DIR}/bin:${PATH}"
STATE_DIR="${ROOT_DIR}/.state"
mkdir -p "${STATE_DIR}"

KEY_FILE="${STATE_DIR}/age.key"
if [[ ! -f "${KEY_FILE}" ]]; then
  echo "[secrets] Generating new local age private key in ${KEY_FILE}..."
  age-keygen -o "${KEY_FILE}"
fi

export SOPS_AGE_KEY_FILE="${KEY_FILE}"
PUBKEY=$(age-keygen -y "${KEY_FILE}")

# Ensure encrypted secret exists and is decryptable by current key
ENC_SECRET="${ROOT_DIR}/secrets/app.enc.yaml"
if [[ ! -f "${ENC_SECRET}" ]] || ! sops -d "${ENC_SECRET}" &>/dev/null; then
  echo "[secrets] Encrypting template secrets/app.example.yaml -> secrets/app.enc.yaml with current age key..."
  sops --encrypt --age "${PUBKEY}" --encrypted-regex '^(data|stringData)$' "${ROOT_DIR}/secrets/app.example.yaml" > "${ENC_SECRET}"
fi

echo "[secrets] Age public key: ${PUBKEY}"
if kubectl cluster-info &>/dev/null; then
  echo "[secrets] Applying decrypted secret to Kubernetes namespace 'demo'..."
  kubectl create namespace demo --dry-run=client -o yaml | kubectl apply -f -
  sops -d "${ENC_SECRET}" | kubectl apply -n demo -f -
  echo "[secrets] Secret 'demo-api-secret' successfully synchronized into cluster."
else
  echo "[secrets] Cluster is currently offline. Secrets verified locally."
fi
