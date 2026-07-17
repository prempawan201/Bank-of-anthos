# dev (environment)

Lightweight, public, standalone dev — for fast iteration and cheap teardown.

## Deploys (single state, single RG)
- Standalone VNet (spoke module, `enable_peering = false`)
- ACR Basic, public (inline)
- Key Vault Standard, public, RBAC (inline)
- AKS public cluster, Free tier

No hub peering, no private endpoints, no private DNS, no postgres, no
workload identity — those are staging/prod only.

## Why public / standalone
A Microsoft-hosted agent (and your laptop) must reach everything directly.
Private endpoints/clusters would require an in-VNet agent — the complexity
dev deliberately avoids. This is why the earlier private-dev hit repeated
403s; the fix was this public posture.

## Cost / lifecycle
- AKS node VMs are the only real cost. Stop at end of day
  (`az aks stop`) or destroy the env.
- ACR Basic, KV Standard, VNet/subnets/NSGs are negligible.
- No Log Analytics (all modules passed null) — no diagnostics cost.
- Secrets in dev KV are Terraform-generated only, so destroy/recreate
  loses nothing. Purge the soft-deleted KV if a same-name recreate
  collides (`az keyvault purge`).

## Notes
- `acr_name` is globally unique — ensure the old `rg-boa-acr-eus2` ACR is
  deleted so the inline dev ACR can take the name.
- The `pipeline_kv_secrets_officer` grant + `time_sleep` only matter if
  something writes secrets to the dev KV; otherwise consider removing them
  (saves 2 min per apply).

## Apply order
Third: hub → dns → **dev** → staging → prod. dev has no cross-env
dependencies, so it can actually be applied any time independently.