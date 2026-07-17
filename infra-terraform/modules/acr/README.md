# acr

Azure Container Registry — stores Bank of Anthos images that AKS pulls.

## When this is used
All environments, built inside each environment's own state (not a shared
registry):

| Env | SKU | Access |
|-----|-----|--------|
| dev | Basic | public |
| staging | Premium | private endpoint |
| prod | Premium | private endpoint |

Premium is required in staging/prod because it's the only SKU supporting
private endpoints.

## What it creates
- The container registry (`admin_enabled = false` — auth is via the AKS
  kubelet managed identity holding AcrPull, never a shared admin login)
- Optional diagnostic setting to Log Analytics when a workspace is supplied

## Posture defaults
Defaults are production-safe: `sku = "Premium"`,
`public_network_access_enabled = true` (flipped to false once the private
endpoint is in place for staging/prod). Dev overrides to `sku = "Basic"`.
`network_rule_bypass_option = "AzureServices"` lets trusted Azure services
(AKS pulls, Defender) through even when public access is off.

## Key inputs
| Variable | Purpose |
|----------|---------|
| `sku` | Basic (dev) vs Premium (staging/prod) |
| `public_network_access_enabled` | public vs private-endpoint-only |
| `log_analytics_workspace_id` | optional diagnostics |

## Key outputs
| Output | Purpose |
|--------|---------|
| `id` | scope for the AcrPull role assignment |
| `login_server` | FQDN for image refs and docker login |
| `name` | registry name |