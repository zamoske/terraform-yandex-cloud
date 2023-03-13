resource "yandex_iam_service_account" "master_sa" {
  name        = "master-sa"
  description = "Service account to kube-cluster(master)"
  folder_id = var.yc_folder_id
}

resource "yandex_resourcemanager_folder_iam_binding" "editor" {
  folder_id = var.yc_folder_id
  role = "editor"
  members = [ 
    "serviceAccount:${yandex_iam_service_account.master_sa.id}", 
    ]
}

resource "yandex_resourcemanager_folder_iam_binding" "k8s-clusters-agent" {
  folder_id = var.yc_folder_id
  role      = "k8s.clusters.agent"
  members = [
    "serviceAccount:${yandex_iam_service_account.master_sa.id}"
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "vpc-public-admin" {
  folder_id = var.yc_folder_id
  role      = "vpc.publicAdmin"
  members = [
    "serviceAccount:${yandex_iam_service_account.master_sa.id}"
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "images-puller" {
  folder_id = var.yc_folder_id
  role      = "container-registry.images.puller"
  members = [
    "serviceAccount:${yandex_iam_service_account.master_sa.id}"
  ]
}

resource "yandex_kubernetes_cluster" "kube_cluster" {
  name        = "my-cluster"
  description = "Master node for kubernetes cluster"
  network_id = "${yandex_vpc_network.k8s_network.id}"
  master {
    version = "1.23"
    regional {
      region = "ru-central1"
      location {
        zone      = "${yandex_vpc_subnet.k8s_network[var.zone[0]].zone}"
        subnet_id = "${yandex_vpc_subnet.k8s_network[var.zone[0]].id}"
      }
      location {
        zone      = "${yandex_vpc_subnet.k8s_network[var.zone[1]].zone}"
        subnet_id = "${yandex_vpc_subnet.k8s_network[var.zone[1]].id}"
      }
      location {
        zone      = "${yandex_vpc_subnet.k8s_network[var.zone[2]].zone}"
        subnet_id = "${yandex_vpc_subnet.k8s_network[var.zone[2]].id}"
      }
    }
    public_ip = true
    security_group_ids = [
      yandex_vpc_security_group.kube_cluster_access.id,
      yandex_vpc_security_group.kube_cluster_main_service.id
    ]
  }
  service_account_id      = "${yandex_iam_service_account.master_sa.id}"
  node_service_account_id = "${yandex_iam_service_account.master_sa.id}"
  release_channel = "STABLE"
  network_policy_provider = "CALICO"
  depends_on = [
    yandex_iam_service_account.master_sa,
  ]
}

resource "yandex_vpc_security_group" "kube_cluster_main_service" {
  name        = "kube-cluster-main-service"
  description = "Правила группы обеспечивают базовую работоспособность кластера. Применяется к кластеру и группам узлов."
  network_id  = "${yandex_vpc_network.k8s_network.id}"
  ingress {
    protocol          = "TCP"
    description       = "Правило разрешает проверки доступности с диапазона адресов балансировщика нагрузки. Нужно для работы отказоустойчивого кластера и сервисов балансировщика."
    predefined_target = "loadbalancer_healthchecks"
    from_port         = 0
    to_port           = 65535
  }
  ingress {
    protocol          = "ANY"
    description       = "Правило разрешает взаимодействие мастер-узел и узел-узел внутри группы безопасности."
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }
  ingress {
    protocol          = "ANY"
    description       = "Правило разрешает взаимодействие под-под и сервис-сервис."
    v4_cidr_blocks    = concat(yandex_vpc_subnet.k8s_network[var.zone[0]].v4_cidr_blocks, yandex_vpc_subnet.k8s_network[var.zone[1]].v4_cidr_blocks, yandex_vpc_subnet.k8s_network[var.zone[2]].v4_cidr_blocks)
    from_port         = 0
    to_port           = 65535
  }
  ingress {
    protocol          = "ICMP"
    description       = "Правило разрешает отладочные ICMP-пакеты из внутренних подсетей."
    v4_cidr_blocks    = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }
  egress {
    protocol          = "ANY"
    description       = "Правило разрешает исходящий трафик. Узлы могут связаться с Yandex Container Registry, Yandex Object Storage, Docker Hub и т. д."
    v4_cidr_blocks    = ["0.0.0.0/0"]
    from_port         = 0
    to_port           = 65535
}
}

resource "yandex_vpc_security_group" "kube_cluster_public_service" {
  name = "kube-cluster-public-service"
  description = "Правила группы разрешают подключение к сервисам из интернета. Применяется только для групп узлов."
  network_id = yandex_vpc_network.k8s_network.id
  ingress {
    protocol       = "TCP"
    description    = "Правило разрешает входящий трафик из интернета на диапазон портов NodePort."
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 30000
    to_port        = 32767
  }
}

resource "yandex_vpc_security_group" "kube_cluster_access" {
  name = "kube-cluster-access"
  description = "Access to kubernetes API"
  network_id = yandex_vpc_network.k8s_network.id
  ingress {
    protocol       = "TCP"
    description    = "Правило разрешает подключение к API Kubernetes через порт 6443 из указанной сети."
    v4_cidr_blocks = ["158.160.0.0/16"]
    port           = 6443
  }

  ingress {
    protocol       = "TCP"
    description    = "Правило разрешает подключение к API Kubernetes через порт 443 из указанной сети."
    v4_cidr_blocks = ["158.160.0.0/16"]
    port           = 443
  }
}

resource "yandex_vpc_security_group" "kube_cluster_nodes_ssh_accesss" {
  name        = "kube-cluster-nodes-ssh-accesss"
  description = "ssh access to node-group"
  network_id  = yandex_vpc_network.k8s_network.id

  ingress {
    protocol       = "TCP"
    description    = "Правило разрешает подключение к узлам по SSH с указанных IP-адресов."
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }
}

resource "yandex_kubernetes_node_group" "kube_cluster" {
  cluster_id = "${yandex_kubernetes_cluster.kube_cluster.id}"
  name = "my-node-group"
  description = "Node group for kubernetes cluster"
  version = "1.23"
  instance_template {
    platform_id = "standard-v2"

    network_interface {
      nat                = true
      subnet_ids         = ["${yandex_vpc_subnet.k8s_network[var.zone[0]].id}"]
      security_group_ids = [
        yandex_vpc_security_group.kube_cluster_nodes_ssh_accesss.id,
        yandex_vpc_security_group.kube_cluster_main_service.id,
        yandex_vpc_security_group.kube_cluster_public_service.id
      ]
    }

    resources {
      memory = 2
      cores  = 2
    }

    boot_disk {
      type = "network-hdd"
      size = 64
    }

    scheduling_policy {
      preemptible = false
    }

    container_runtime {
      type = "docker"
    }
    metadata = {
      ssh-keys = "ubuntu:${var.ssh_key}"
    }
  }
  scale_policy {
    fixed_scale {
      size = 1
    }
  }
  allocation_policy {
    location {
      zone = "${yandex_vpc_subnet.k8s_network[var.zone[0]].zone}"
    }
  }
  depends_on = [
    yandex_kubernetes_cluster.kube_cluster,
  ]
}