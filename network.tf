resource "yandex_vpc_network" "k8s_network" {
  name = "k8s-network"
}

resource "yandex_vpc_subnet" "k8s_network" {
  for_each = toset (var.zone)
  name = "subnet-${each.value}"
  zone           = each.value
  network_id     = yandex_vpc_network.k8s_network.id
  v4_cidr_blocks = var.cidr_blocks[index(var.zone, each.value)]
}