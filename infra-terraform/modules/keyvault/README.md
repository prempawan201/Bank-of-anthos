# keyvault

Azure Key Vault for platform secrets — Postgres passwords, and in staging
the Azure DevOps agent PAT. RBAC-authorized, secrets-only.

## When this is used
All environments. One module, two postures:

| Env | SKU | Access | ACL default |
|-----|-----|--------|-------------|
| dev | Standard | public | Allow |
| staging | Standard | private endpoint | Deny |
| prod | Standard | private endpoint | Deny |

## Why Standard everywhere (not Premium)
Premium's only advantage is HSM-backed cryptographic **keys**. This vault
holds **secrets** (passwords, tokens), which are identical on both SKUs.
Premium would add cost for nothing. Only switch an env to Premium if a
compliance mandate requires HSM-backed key material.

## Lifecycle — lives in its own env
The vault is deployed from a dedicated `dev-keyvault/` env with its own
persistent state and resource group, separate from the ephemeral workload
env (`dev/`). The nightly `terraform destroy` of the workload env never
touches it, so secrets survive teardown. Consumers (`dev/`) read the vault
ID/URI via `terraform_remote_state`.

This mirrors the existing `dns/` and `hub/` persistent-env pattern.

## RBAC mode
`enable_rbac_authorization = true` — permissions come from Azure role
assignments, not access policies. The `admin` role assignment is
mandatory: in RBAC mode, without a role even the vault creator cannot read
secrets.

## Secrets handling on recreate
- **Terraform-generated secrets** (Postgres passwords via `random_password`)
  are re-minted automatically on every apply — nothing to hand-feed.
- **External secrets** (the ADO agent PAT) are seeded from a Key Vault
  secret resource whose value comes from an Azure DevOps secret pipeline
  variable — entered in ADO once, re-applied automatically. Kept in code,
  never pasted manually.

## Posture defaults
Defaults are production-safe: `public_network_access_enabled = false`,
`network_acls_default_action = "Deny"`. Dev overrides both to public/Allow.

## Key inputs
| Variable | Purpose |
|----------|---------|
| `public_network_access_enabled` | public (dev) vs private (staging/prod) |
| `network_acls_default_action` | Allow (dev) vs Deny (staging/prod) |
| `admin_object_id` | human admin granted Key Vault Administrator |
| `purge_protection_enabled` | false dev/qa, true prod |
| `log_analytics_workspace_id` | optional audit logging |

## Key outputs
| Output | Purpose |
|--------|---------|
| `id` | scope for secret role assignments; read by consumers |
| `uri` | data-plane URI for apps and the agent PAT fetch |
| `name` | vault name |