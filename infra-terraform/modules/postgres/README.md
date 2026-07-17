# postgres

PostgreSQL Flexible Server (VNet-integrated, private) backing Bank of
Anthos — the accounts and ledger databases.

## When this is used
**Staging and prod only.** This is a private, VNet-integrated server
(`delegated_subnet_id` + `private_dns_zone_id`), and that model is mutually
exclusive with public access — there is no public dev toggle. Dev does not
deploy this module; for a database in dev, use an in-cluster Postgres pod
or a separate public-Postgres variant. Part of the staging/prod private
data tier.

## File layout
| File | Contains |
|------|----------|
| `main.tf` | the server, admin password + KV secret, server configs, diagnostics |
| `database.tf` | the databases, per-app passwords, per-app KV secrets |
| `variables.tf` | server-level variables |
| `outputs.tf` | server-level outputs |

Database-level variables (`databases`, `application_passwords`) and outputs
(`database_names`, `app_password_secret_ids`) live in `database.tf` next to
the resources they describe.

## What it creates
- A private Flexible Server (VNet-integrated, no public access)
- The `accounts` and `ledger` databases
- A 32-char admin password + per-app passwords, all `random_password`-
  generated and written to Key Vault (nothing hand-fed)
- Server configs: connection throttling, checkpoint/connection logging,
  extensions
- Optional diagnostics to Log Analytics

## Authentication
Dual auth: Entra AD (`active_directory_auth_enabled`) plus password auth.
Apps use the KV-stored passwords in their connection strings; AD auth is
available for admin/operational access.

## Secrets on recreate
All passwords are Terraform-generated and pushed to KV on every apply.
Destroy and recreate freely — fresh credentials are minted and stored
automatically. No manual re-feeding.

## Cost levers (run cheap)
- `sku_name`: `B_Standard_B1ms` (burstable) for staging practice; bump to a
  General Purpose SKU only when demonstrating prod-like sizing.
- `geo_redundant_backup_enabled`: leave false unless practicing DR.
- `storage_mb`: 32 GB minimum is plenty for the demo.
Stand it up to practice, then destroy with the env.

## Known items
- **Extensions config (`azure.extensions`)**: the resource is named
  `pgaadauth` but its value omits `pgaadauth` while AD auth is enabled.
  Reconcile name vs value before relying on AD-auth extension behaviour
  (see inline flag in `main.tf`).
- **Admin password expiry** uses `timestamp()`, which drifts each plan;
  neutralized by `ignore_changes = [expiration_date]`.

## Production deltas
- Set `prevent_destroy = true` on databases (in `database.tf`) for prod.
- Consider geo-redundant backups and a General Purpose SKU.

## Key inputs
| Variable | Purpose |
|----------|---------|
| `sku_name` | size / cost lever |
| `delegated_subnet_id` | VNet integration subnet (private model) |
| `private_dns_zone_id` | privatelink.postgres zone |
| `key_vault_id` | where generated passwords are stored |
| `databases`, `application_passwords` | which DBs and per-app creds to create (in database.tf) |

## Key outputs
| Output | Source file | Purpose |
|--------|-------------|---------|
| `fqdn` | outputs.tf | private DNS name for app connection strings |
| `admin_password_kv_secret_id` | outputs.tf | KV secret ID for admin |
| `app_password_secret_ids` | database.tf | KV secret IDs per app |
| `database_names` | database.tf | created database names |

## Version note
`postgres_version = "16"` — well-supported. PG 17 is GA; bump deliberately
and verify Azure Flexible Server supports the target version in your region.