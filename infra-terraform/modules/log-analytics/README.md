# log-analytics

Central Log Analytics workspace — the log and metric sink for the platform.

## When this is used
**Staging and prod only.** Deployed in the hub (shared, persistent) so all
environments report into one workspace. **Dev does not use this** — dev
passes `log_analytics_workspace_id = null` to every module, so no
diagnostic settings or Container Insights are created. That's a deliberate
dev cost saving: observability is a staging/prod concern, and Log Analytics
bills per GB ingested.

## What it creates
A single Log Analytics workspace. Other modules reference its `id` to wire:
- ACR diagnostic settings (login/repository events)
- Key Vault diagnostic settings (audit events)
- AKS Container Insights (oms_agent)

## Cost levers
- `sku = PerGB2018` — pay per GB ingested. The cost scales with how much
  telemetry the platform emits, so chatty diagnostics in staging/prod add up.
- `retention_in_days = 30` — 30 days is the included retention; raising it
  bills extra. Keep at 30 unless an audit requirement forces longer.

For a learning project, stand this up only while actively practicing
staging/prod observability, then destroy it with the rest of the env.

## Key inputs
| Variable | Purpose |
|----------|---------|
| `sku` | pricing model (PerGB2018) |
| `retention_in_days` | data retention window (cost lever) |

## Key outputs
| Output | Purpose |
|--------|---------|
| `id` | passed as `log_analytics_workspace_id` to ACR/KV/AKS |
| `workspace_id` | GUID for agent/SDK-based ingestion |
| `primary_key` | shared key for agent ingestion (sensitive) |