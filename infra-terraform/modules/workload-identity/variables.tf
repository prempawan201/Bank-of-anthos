variable "app_name" {
  description = "Display name for the Entra ID app registration (e.g. boa-accounts-svc-staging)"
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace where the ServiceAccount lives"
  type        = string
}

variable "k8s_service_account_name" {
  description = "Name of the Kubernetes ServiceAccount this identity federates to"
  type        = string
}

variable "aks_oidc_issuer_url" {
  description = "OIDC issuer URL from the AKS cluster. Changes when the cluster is recreated — this module must be recreated with it."
  type        = string
}