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
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.19.0"
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
  cluster_name = var.cluster_name
}

module "iam" {
  source = "./modules/iam"
  cars_arn = module.ecr.ecr_cars_repository_arn
  docker_arn = module.ecr.ecr_docker_repository_arn
  rds_arn = module.rds.rds_arn
}

module "security" {
  source   = "./modules/security"
  vpc_id   = module.network.vpc_id
  subnet_cidr = module.network.eks_subnet_a_cidr
  region = var.region
  route_private = module.network.route_private
  db_subnet_a_id = module.network.db_subnet_a_id
  db_subnet_b_id = module.network.db_subnet_b_id
  eks_subnet_ids = module.network.eks_subnet_ids
}

module "ecr" {
  source   = "./modules/ecr"
  cars_name   = "cars"
  docker_name = "docker"
  mutability = "MUTABLE"
}

module "eks" {
  source             = "./modules/eks"
  cluster_name       = var.cluster_name
  subnet_ids         = module.network.eks_subnet_ids
  cluster_role_arn   = module.iam.eks_cluster_role_arn
  jumpbox_role_arn   = module.iam.jumpbox_role_arn
  node_role_arn      = module.iam.eks_node_role_arn
  security_group_id  = module.security.eks_sg_id
  public_cluster     = var.public_cluster
  github_token       = var.github_token
}

module "endpoints" {
  source             = "./modules/endpoints"
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.eks_subnet_ids
  security_group_ids = [module.security.eks_sg_id]
  region             = var.region
}

module "rds"{
  source = "./modules/rds"
  db_subnet_a_id = module.network.db_subnet_a_id
  db_subnet_b_id = module.network.db_subnet_b_id
  db_sg_id = module.security.db_sg_id
}

output "eks_endpoint" {
  value = module.eks.endpoint
}
