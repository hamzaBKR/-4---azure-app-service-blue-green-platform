#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID="${1:?subscription id required}"
GITHUB_OWNER="${2:?github owner required}"
GITHUB_REPO="${3:?github repo required}"
BRANCH="${4:-main}"

APP_NAME="gh-${GITHUB_REPO}-oidc"
SUBJECT="repo:${GITHUB_OWNER}/${GITHUB_REPO}:ref:refs/heads/${BRANCH}"

az account set --subscription "$SUBSCRIPTION_ID"

APP_ID="$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)"
APP_OBJECT_ID="$(az ad app show --id "$APP_ID" --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"

az ad sp create --id "$APP_ID" >/dev/null

az role assignment create \
  --assignee "$APP_ID" \
  --role Contributor \
  --scope "/subscriptions/${SUBSCRIPTION_ID}" >/dev/null

cat > /tmp/federated-credential.json <<EOF
{
  "name": "github-${BRANCH}",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "${SUBJECT}",
  "description": "GitHub Actions OIDC for ${GITHUB_OWNER}/${GITHUB_REPO}",
  "audiences": ["api://AzureADTokenExchange"]
}
EOF

az ad app federated-credential create \
  --id "$APP_OBJECT_ID" \
  --parameters /tmp/federated-credential.json >/dev/null

echo "AZURE_CLIENT_ID=${APP_ID}"
echo "AZURE_TENANT_ID=${TENANT_ID}"
echo "AZURE_SUBSCRIPTION_ID=${SUBSCRIPTION_ID}"
