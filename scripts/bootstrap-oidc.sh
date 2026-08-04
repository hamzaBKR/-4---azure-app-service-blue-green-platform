#!/usr/bin/env bash

# Stop on:
# - any failed command
# - undefined variables
# - failures inside command pipelines
set -euo pipefail

# ---------- INPUTS PROVIDED BY YOU ----------

# Azure subscription containing the project resource group.
SUBSCRIPTION_ID="${1:?subscription ID is required}"

# Existing resource group that GitHub Actions may manage.
RESOURCE_GROUP="${2:?resource group name is required}"

# Exact GitHub repository owner from:
# github.com/<OWNER>/<REPOSITORY>
GITHUB_OWNER="${3:?GitHub owner is required}"

# Exact repository name.
GITHUB_REPO="${4:?GitHub repository is required}"

# GitHub environment used in the deployment workflow.
GITHUB_ENVIRONMENT="${5:-development}"


# ---------- GENERATED VALUES ----------

# Friendly name shown in Microsoft Entra ID.
APP_DISPLAY_NAME="github-${GITHUB_REPO}-deployment"

# Exact GitHub identity Azure will trust.
FEDERATED_SUBJECT="repo:${GITHUB_OWNER}/${GITHUB_REPO}:environment:${GITHUB_ENVIRONMENT}"


# ---------- SELECT AZURE SUBSCRIPTION ----------

# Ensure every following Azure command targets the correct subscription.
az account set --subscription "$SUBSCRIPTION_ID"


# ---------- VERIFY RESOURCE GROUP ----------

# Stop if the resource group does not already exist.
az group show \
  --name "$RESOURCE_GROUP" \
  --output none


# ---------- CREATE ENTRA APPLICATION ----------

# Create the application registration and capture its client/application ID.
CLIENT_ID="$(
  az ad app create \
    --display-name "$APP_DISPLAY_NAME" \
    --query appId \
    --output tsv
)"

# Get the application object's internal Entra object ID.
APPLICATION_OBJECT_ID="$(
  az ad app show \
    --id "$CLIENT_ID" \
    --query id \
    --output tsv
)"


# ---------- CREATE SERVICE PRINCIPAL ----------

# Create the Azure identity instance that can receive RBAC permissions.
az ad sp create \
  --id "$CLIENT_ID" \
  --output none


# ---------- ASSIGN LEAST-PRIVILEGE SCOPE ----------

# Build the exact resource-group scope.
RESOURCE_GROUP_SCOPE="$(
  az group show \
    --name "$RESOURCE_GROUP" \
    --query id \
    --output tsv
)"

# Give the identity Contributor only inside this project resource group.
az role assignment create \
  --assignee "$CLIENT_ID" \
  --role "Contributor" \
  --scope "$RESOURCE_GROUP_SCOPE" \
  --output none


# ---------- CONFIGURE GITHUB OIDC TRUST ----------

# Create the federated credential definition.
cat > /tmp/github-federated-credential.json <<EOF
{
  "name": "github-${GITHUB_ENVIRONMENT}",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "${FEDERATED_SUBJECT}",
  "description": "OIDC trust for ${GITHUB_OWNER}/${GITHUB_REPO}",
  "audiences": [
    "api://AzureADTokenExchange"
  ]
}
EOF

# Attach the GitHub trust definition to the Entra application.
az ad app federated-credential create \
  --id "$APPLICATION_OBJECT_ID" \
  --parameters /tmp/github-federated-credential.json \
  --output none


# ---------- PRINT GITHUB VALUES ----------

TENANT_ID="$(
  az account show \
    --query tenantId \
    --output tsv
)"

echo
echo "OIDC configuration completed."
echo
echo "Add these values to GitHub:"
echo "AZURE_CLIENT_ID=${CLIENT_ID}"
echo "AZURE_TENANT_ID=${TENANT_ID}"
echo "AZURE_SUBSCRIPTION_ID=${SUBSCRIPTION_ID}"
echo "AZURE_RESOURCE_GROUP=${RESOURCE_GROUP}"
echo
echo "Permission scope:"
echo "${RESOURCE_GROUP_SCOPE}"