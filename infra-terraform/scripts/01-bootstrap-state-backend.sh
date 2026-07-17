#!/bin/bash
set -euo pipefail
# ── Bootstrap: Create Terraform remote state backend ─────────────────────
# Run once before terraform init. Idempotent — safe to re-run.

RESOURCE_GROUP="rg-boa-bootstrap-eus2"
STORAGE_ACCOUNT="stboatfstate$(shuf -i 1000-9999 -n 1)"
CONTAINER_NAME="tfstate"
LOCATION="eastus2"

TAGS="environment=shared workload=bank-of-anthos owner=prem lifecycle=bootstrap managed-by=manual cost-center=learning"

echo "==> Checking Azure login"
az account show --output table

echo "==> Creating resource group: $RESOURCE_GROUP"
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --tags $TAGS \
  --output table

echo "==> Creating storage account: $STORAGE_ACCOUNT"
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_ZRS \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --tags $TAGS \
  --output table

echo "==> Enabling blob versioning"
az storage account blob-service-properties update \
  --account-name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --enable-versioning true \
  --output table

echo "==> Enabling soft delete (7 day retention)"
az storage account blob-service-properties update \
  --account-name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --delete-retention-days 7 \
  --enable-delete-retention true \
  --output table

echo "==> Creating blob container: $CONTAINER_NAME"
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login \
  --output table

echo ""
echo "✅ Bootstrap complete."
echo "   Resource group : $RESOURCE_GROUP"
echo "   Storage account: $STORAGE_ACCOUNT"
echo "   Container      : $CONTAINER_NAME"
echo ""
echo "Next: run terraform init in infra-terraform/"
