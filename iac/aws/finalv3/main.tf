terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_region" "current" {}

module "network" {
  source = "./modules/network"
  region = var.region
}

module "iam" {
  source = "./modules/iam"
}

module "security" {
  source   = "./modules/security"
  vpc_id   = module.network.vpc_id
  subnet_cidr = module.network.eks_subnet_a_cidr
}

module "eks" {
  source             = "./modules/eks"
  cluster_name       = var.cluster_name
  subnet_ids         = module.network.eks_subnet_ids
  cluster_role_arn   = module.iam.eks_cluster_role_arn
  jumpbox_role_arn   = module.iam.jumpbox_role_arn
  security_group_id  = module.security.eks_sg_id
  public_cluster     = var.public_cluster
}

module "endpoints" {
  source             = "./modules/endpoints"
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.eks_subnet_ids
  security_group_ids = [module.security.eks_sg_id]
  region             = var.region
}

module "compute" {
  source              = "./modules/compute"
  admin_subnet_id     = module.network.admin_subnet_id
  eks_subnet_id       = module.network.eks_subnet_a_id
  ssh_sg_id           = module.security.ssh_sg_id
  jumpbox_sg_id       = module.security.eks_sg_id
  private_key_pem     = module.security.private_key_pem
  key_pair_name       = module.security.key_pair_name
  iam_instance_profile = module.iam.jumpbox_profile
  jumpbox_ip          = module.compute.jumpbox_private_ip
  admin_vm_script     = var.admin_vm_script
  rpms_file           = var.rpms_file
  jumpbox_setup_file = var.jumpbox_setup_file
}

output "admin_vm_public_ip" {
  value = module.compute.admin_public_ip
}

output "jumpbox_ip" {
  value = module.compute.jumpbox_private_ip
}

output "eks_endpoint" {
  value = module.eks.endpoint
}

output "private_key_pem" {
  description = "Private key for SSH access to EC2 instances"
  value       = module.security.private_key_pem
  sensitive   = true
}
