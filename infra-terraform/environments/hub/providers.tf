# ============================================================
# providers.tf
# ------------------------------------------------------------
# azurerm provider configuration. OIDC auth (workload-identity
# federation via the pipeline service connection) — no stored
# secret. The features block tunes destroy behaviour:
#   - prevent_deletion_if_contains_resources = false: allow RG
#     destroy even if non-empty (convenient teardown, fine for a
#     learning platform).
#   - purge_soft_delete_on_destroy = true: fully purge a KV on
#     destroy rather than leaving it in soft-delete (avoids the
#     name-collision-on-recreate problem).
#   - recover_soft_deleted_key_vaults = true: if a soft-deleted KV
#     of the same name exists, recover it instead of failing.
# ============================================================
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }

  subscription_id = var.subscription_id
  use_oidc        = true
}