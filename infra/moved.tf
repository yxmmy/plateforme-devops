# Conserve les ressources existantes lors du passage aux modules.
moved {
  from = kind_cluster.plateforme
  to   = module.cluster.kind_cluster.this
}

moved {
  from = helm_release.argocd
  to   = module.argocd.helm_release.argocd
}
