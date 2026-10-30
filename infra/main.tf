resource "kind_cluster" "plateforme" {
  name           = "plateforme"
  wait_for_ready = true
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.10.3"
  timeout          = 600
}
