resource "yandex_mdb_postgresql_cluster" "yelb_db" {
    name = "yelb"
    environment = "PRESTABLE"
    network_id = yandex_vpc_network.k8s_network.id
    security_group_ids = [yandex_vpc_security_group.yelb_db_1.id]
    deletion_protection = false
    config {
        version = var.db_version
        resources {
          resource_preset_id = var.preset_id
          disk_type_id = "network-hdd"
          disk_size = var.disk_size
        }
    }
    host {
      name = "yelb-db-host"
      zone = "${yandex_vpc_subnet.k8s_network[var.zone[0]].zone}"
      subnet_id = "${yandex_vpc_subnet.k8s_network[var.zone[0]].id}"
      assign_public_ip = true
    }
}

resource "yandex_mdb_postgresql_database" "yelb_db" {
  cluster_id = yandex_mdb_postgresql_cluster.yelb_db.id
  name = "yelb-db"
  owner = yandex_mdb_postgresql_user.yelb_db.name
  depends_on = [
    yandex_mdb_postgresql_user.yelb_db
  ]
}

resource "yandex_mdb_postgresql_user" "yelb_db" {
  cluster_id = yandex_mdb_postgresql_cluster.yelb_db.id
  name = var.db_user
  password = var.db_passwd
}

resource "yandex_vpc_security_group" "yelb_db_1" {
    name        = "yelb-db"
    description = "Connecting to database through specific port"
    network_id  = "${yandex_vpc_network.k8s_network.id}"
    ingress {
    port = 6432
    protocol = "TCP"
    v4_cidr_blocks    = ["0.0.0.0/0"]
    description = "PostgreSQL"
  }
}
