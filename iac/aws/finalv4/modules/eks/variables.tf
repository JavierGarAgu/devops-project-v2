variable "cluster_name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "cluster_role_arn" {
  type = string
}

variable "node_role_arn" {
  type = string
}

variable "jumpbox_role_arn" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "github_token" {
  type = string
}

variable "public_cluster" {
  type = bool
}
