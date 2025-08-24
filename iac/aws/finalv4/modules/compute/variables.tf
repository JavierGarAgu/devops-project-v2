variable "admin_subnet_id" {
  type = string
}

variable "eks_subnet_id" {
  type = string
}

variable "ssh_sg_id" {
  type = string
}

variable "jumpbox_sg_id" {
  type = string
}

variable "private_key_pem" {
  type      = string
  sensitive = true
}

variable "key_pair_name" {
  type = string
}

variable "iam_instance_profile" {
  type = string
}

variable "jumpbox_ip" {
  type = string
}

variable "admin_vm_script" {
  type = string
}

variable "rpms_file" {
  type = string
}

variable "jumpbox_setup_file" {
  type = string
}

variable "sql_file" {
  type = string
}

variable "phostname" {
  type = string
}

variable "rds_arn" {
  type = string
}