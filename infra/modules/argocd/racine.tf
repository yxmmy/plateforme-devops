resource "helm_release" "racine" {
  name       = "racine"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = "2.0.6"

  depends_on = [helm_release.argocd]

  values = [yamlencode({
    applications = {
      racine = {
        namespace = "argocd"
        project   = "default"
        source = {
          repoURL        = var.depot
          targetRevision = "main"
          path           = "deploy/argocd"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "argocd"
        }
        syncPolicy = {
          automated = {
            prune    = true
            selfHeal = true
          }
        }
      }
    }
  })]
}
