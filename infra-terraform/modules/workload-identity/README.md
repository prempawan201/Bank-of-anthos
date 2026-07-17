# workload-identity

Entra Workload Identity federation — lets a Kubernetes ServiceAccount
authenticate to Azure with no stored secret.

## When this is used
**Staging and prod only.** Dev does not use this; dev injects secrets via
plain Kubernetes secrets or pipeline variables. Workload Identity is the
secretless production pattern.

## What it creates
- An Entra application registration
- Its service principal (the RBAC target)
- A federated identity credential linking a specific K8s ServiceAccount to
  the app via the AKS OIDC issuer

## The trust chain (secretless)
1. AKS projects an OIDC token into the pod for its ServiceAccount.
2. The federated credential tells Entra to trust tokens from that issuer
   for that exact `namespace:serviceaccount` subject.
3. Entra issues an access token for the app/SP.
4. Azure RBAC roles on the SP authorize what it can reach (e.g. KV secrets).

No client secret is ever created or stored.

## ⚠ Two failure modes (these caused real issues earlier)

**1. Orphaned app registrations.** These are tenant-level Entra objects, not
resources in the workload RG. Deleting the RG does NOT remove them — only
`terraform destroy` does. If the env is torn down by deleting the RG, or
state is lost, the app registrations leak in Entra (this is why
`boa-accounts-svc-dev` was found lingering). Always destroy through
Terraform.

**2. Issuer coupling.** The federated credential pins to the AKS cluster's
OIDC issuer URL. A destroyed-and-recreated cluster gets a brand-new issuer
URL, so this module must be recreated alongside the cluster — otherwise
federation fails silently with a token issuer mismatch. Keep this module's
lifecycle tied to the cluster.

## Usage pattern
For each app service needing Azure access, instantiate this module once
(per service), then:
1. Annotate the K8s ServiceAccount with `client_id` (use `annotation_value`).
2. Grant the `service_principal_object_id` the Azure roles it needs (e.g.
   Key Vault Secrets User) in the environment root.

## Key inputs
| Variable | Purpose |
|----------|---------|
| `app_name` | Entra app registration display name |
| `k8s_namespace` / `k8s_service_account_name` | the SA this identity trusts |
| `aks_oidc_issuer_url` | cluster issuer — recreate this module if it changes |

## Key outputs
| Output | Purpose |
|--------|---------|
| `client_id` | annotate the ServiceAccount with this |
| `service_principal_object_id` | target for Azure RBAC role assignments |
| `annotation_value` | ready-made SA annotation line |