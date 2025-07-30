locals {
  interface_services = [
    "eks",
    "eks-auth",
    "ec2",
    "sts",
    "logs",
    "ecr.api",
    "ecr.dkr",
    "elasticloadbalancing"
  ]
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(local.interface_services)

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = var.security_group_ids
  private_dns_enabled = true

  tags = {
    Name = "vpce-${each.key}"
  }
}
