variable "nom_cluster" {
  description = "Nom du cluster kind local."
  type        = string
}

variable "version_argocd" {
  description = "Version du chart Helm argo-cd."
  type        = string
}

variable "depot" {
  description = "URL HTTPS du dépôt Git lu par ArgoCD."
  type        = string
}
