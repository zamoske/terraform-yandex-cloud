variable "zone" {
  type = list(string)
  default = [ 
    "ru-central1-a",
    "ru-central1-b",
    "ru-central1-c" 
]
  description = "Zone for network interface"
}

variable "cidr_blocks" {
  type = list(list(string))
  description = "List of IPv4 cidr blocks for subnets"
  default = [
    ["10.10.0.0/24"],
    ["10.11.0.0/24"],
    ["10.12.0.0/24"] 
  ]
}

variable "yc_folder_id" {
  type = string
  description = "yandex cloud folder id"
}

variable "yc_token" {
  type = string
  description = "yandex cloud token"
}

variable "yc_cloud_id" {
  type = string
  description = "yandex cloud id"
}

variable "ssh_key" {
  type = string
  description = "ssh key to connect kubernetes node group"
}

variable "db_version" {
  type = string
  default = "15"
}

variable "db_user" {
  type = string
  default = "slurm-s045012"
  description = "user for database"
}

variable "db_passwd" {
  type = string
  description = "password for database"
}

variable "preset_id" {
  type = string
  default = "b1.nano"
  description = "resource preset id for database"
}

variable "disk_size" {
  type = number
  default = 20
  description = "disk size for database"
}