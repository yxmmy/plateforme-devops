provider "helm" {
  kubernetes = {
    host                   = kind_cluster.plateforme.endpoint
    client_certificate     = kind_cluster.plateforme.client_certificate
    client_key             = kind_cluster.plateforme.client_key
    cluster_ca_certificate = kind_cluster.plateforme.cluster_ca_certificate
  }
}
