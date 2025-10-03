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

data "aws_region" "current" {}

module "network" {
  source = "./modules/network"
}

module "iam" {
  source = "./modules/iam"
  arc_namespace = var.arc_namespace
}


module "ecr" {
  source   = "./modules/ecr"
}

module "ec2" {
  source   = "./modules/ec2"
}

module "eks" {
  source             = "./modules/eks"
}

module "inside_eks" {
  source             = "./modules/inside_eks"
  github_token = var.github_token
  arc_namespace = var.arc_namespace
}

module "rds"{
  source = "./modules/rds"
}

output "eks_endpoint" {
  value = module.eks.endpoint
}
