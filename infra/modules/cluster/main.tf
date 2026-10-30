resource "kind_cluster" "this" {
  name           = var.nom
  wait_for_ready = true
}
