variable "vpc_id" {
  type = string
}

variable "subnet_cidr" {
  type = string
}

variable "region" {
  type = string
}

variable route_private {
  type = string
}

variable db_subnet_a_id {
  type = string
}

variable db_subnet_b_id {
  type = string
}

variable eks_subnet_ids {
  type = list(string)
}