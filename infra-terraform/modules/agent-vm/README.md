# agent-vm

Self-hosted Azure DevOps agent VM in the hub, with selectable auth mode.

## When this is used
**Staging and prod only.** Dev uses Microsoft-hosted agents. This in-VNet
agent exists to deploy private clusters / private endpoints that hosted
agents can't reach.

## Auth modes (var.agent_auth_mode)
A deliberate selectable mode — **not** runtime failover. You pick one and
apply; there is no silent fallback.

| Mode | How it authenticates to ADO | Identity | KV-PAT plumbing |
|------|----------------------------|----------|-----------------|
| `pat` (default) | MSI reads a PAT from Key Vault, registers with `--auth pat` | system-assigned | required |
| `managed_identity` | VM's user-assigned identity authenticates directly to ADO, no PAT | user-assigned | none |

Switch by changing the variable and re-applying. If MID misbehaves, set
`pat` and re-apply for the proven path — deterministic, not automatic.

## PAT mode
- VM gets a system-assigned identity.
- `vm_kv_read` grants that identity Key Vault Secrets User on `keyvault_id`.
- A `time_sleep` absorbs RBAC propagation lag so cloud-init's PAT read
  doesn't 403 on a not-yet-propagated grant.
- cloud-init fetches the PAT via MSI and registers with it.
- Requires: a PAT secret in KV at `azdo_pat_kv_uri`, and `keyvault_id`.

## Managed-identity mode
- VM gets a user-assigned identity (stable `client_id`).
- No PAT, no KV-PAT role, no PAT secret.
- cloud-init registers with `--auth managedidentity --clientId <uami>`.
- **One-time ADO-org bootstrap (not Terraform-native):** the UAMI must be
  added to the Azure DevOps org as a member with a Basic license, and
  granted Agent Pools (Read & Manage) + pool Administrator. Output
  `uami_client_id` gives you the client_id to register.
- This is the PAT-free production pattern — nothing to rotate.

## Why managed-identity mode doesn't hit the dev KV 403
The dev 403 was a network-position problem (hosted agent outside the VNet
vs a Deny-default private vault). This agent is in-VNet with a private
endpoint + DNS link, so it reaches private KV over the private path the
Deny firewall permits. The auth mode doesn't change that — registration
talks to ADO, not KV. (For deployment *work* the VM identity still needs
Secrets User on the staging KV, granted in the staging root, in both modes.)

## Version note
cloud-init pins Terraform to match platform/state. kubectl/Helm/CLI/agent
are fetched latest at boot. Bump the Terraform pin in lockstep with the
pipeline task, root `required_version`, and local binary.

## Key inputs
| Variable | Mode | Purpose |
|----------|------|---------|
| `agent_auth_mode` | both | "pat" or "managed_identity" |
| `azdo_pat_kv_uri` | pat | KV secret URI for the PAT |
| `keyvault_id` | pat | KV scope for Secrets User grant |
| `ssh_public_key`, `subnet_id`, `azdo_org_url`, `azdo_pool_name` | both | base config |

## Key outputs
| Output | Purpose |
|--------|---------|
| `principal_id` | VM identity principal (source differs by mode) — grant ACR/AKS/KV roles |
| `uami_client_id` | MID mode: client_id to register in ADO org (empty in PAT mode) |
| `private_ip` | spoke NSG rules, SSH |