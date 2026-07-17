# ============================================================
# modules/workload-identity — Entra Workload Identity federation
# ------------------------------------------------------------
# STAGING/PROD ONLY. Dev does NOT use this — dev injects secrets
# via plain K8s secrets / pipeline vars.
#
# Lets a Kubernetes ServiceAccount authenticate to Entra (and thus
# to Key Vault, etc.) WITHOUT any stored secret. The trust chain:
#   K8s SA → projected OIDC token → federated credential → Entra
#   app/SP → Azure RBAC role. Fully secretless.
#
# ⚠ LEAK RISK — these are TENANT-LEVEL objects, not RG resources.
# Deleting the workload resource group does NOT remove them; only
# `terraform destroy` on this module does. If the env is torn down
# by deleting the RG (or state is lost), these app registrations
# orphan in Entra (this is why boa-accounts-svc-dev lingered). They
# must be destroyed through Terraform, not the portal.
#
# ⚠ ISSUER COUPLING — the federated credential below pins to the
# AKS OIDC issuer URL. A destroyed+recreated cluster gets a NEW
# issuer URL, so this credential must be recreated alongside the
# cluster or federation silently fails (token issuer mismatch).
# Keep this module's lifecycle tied to the cluster's.
# ============================================================

# The Entra application object — the identity definition.
resource "azuread_application" "this" {
  display_name = var.app_name
}

# The service principal — the usable instance of that app in this
# tenant, the thing Azure RBAC role assignments target.
resource "azuread_service_principal" "this" {
  client_id = azuread_application.this.client_id
}

# The federated credential — the trust link. It tells Entra:
# "accept OIDC tokens from THIS AKS issuer, for THIS exact
# namespace/serviceaccount subject, and treat them as this app."
# No client secret involved — the K8s projected token is the proof.
resource "azuread_application_federated_identity_credential" "this" {
  application_id = azuread_application.this.id
  display_name   = "k8s-${var.k8s_namespace}-${var.k8s_service_account_name}"
  description    = "Federated credential for SA ${var.k8s_namespace}/${var.k8s_service_account_name}"

  # Required audience for Entra workload-identity token exchange.
  audiences = ["api://AzureADTokenExchange"]

  # The cluster's OIDC issuer — the coupling point flagged above.
  issuer = var.aks_oidc_issuer_url

  # The exact SA this credential trusts. Format is fixed by the
  # workload-identity spec: system:serviceaccount:<ns>:<name>.
  # A mismatch here = silent auth failure.
  subject = "system:serviceaccount:${var.k8s_namespace}:${var.k8s_service_account_name}"
} 