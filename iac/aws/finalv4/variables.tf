variable "region" {
  default = "eu-north-1"
}

variable "cluster_name" {
  default = "my-private-eks"
}

variable "public_cluster" {
  default = true
}

variable "admin_vm_script" {
  default = "./setup_admin.sh"
}

variable "rpms_file" {
  default = "./bin/rpms.tar.gz"
}

variable "sql_file" {
  default = "./bin/init.sql"
}

variable "jumpbox_setup_file" {
  default = "./setup_jumpbox.sh"
}

variable "github_token" {
  description = "GitHub Personal Access Token for actions-runner-controller"
  type        = string
  sensitive   = true
}