module "cluster" {
  source = "./modules/cluster"
  nom    = var.nom_cluster
}

module "argocd" {
  source        = "./modules/argocd"
  version_chart = var.version_argocd
  depot         = var.depot

  depends_on = [module.cluster]
}
