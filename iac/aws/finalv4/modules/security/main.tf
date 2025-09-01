# -----------------------------
# Security Group for EKS Node Group
# -----------------------------
resource "aws_security_group" "eks_nodes_sg" {
  name        = "eks-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  # Allow all node-to-node traffic within the cluster
  ingress {
    from_port                = 0
    to_port                  = 0
    protocol                 = "-1"
    self                     = true
    description              = "Node-to-node communication"
  }

  # Allow all egress (nodes can pull images, reach NAT)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "eks-nodes-sg" }
}

# -----------------------------
# Security Group for Database
# -----------------------------
resource "aws_security_group" "db_sg" {
  name        = "private-db-sg"
  description = "Database access restricted to jumpbox and optionally EKS nodes"
  vpc_id      = var.vpc_id

  # No inline ingress; will add rules separately
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "private-db-sg" }
}

# ----------------------------
# Database Ingress: EKS Nodes (optional)
# -----------------------------
resource "aws_security_group_rule" "db_ingress_from_eks_nodes" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db_sg.id
  source_security_group_id = aws_security_group.eks_nodes_sg.id
  description              = "Postgres access from EKS nodes"
}

# -----------------------------
# Security Group for VPC Endpoints
# -----------------------------
resource "aws_security_group" "vpc_endpoints_sg" {
  name        = "vpc-endpoints-sg"
  description = "Allow EKS nodes to reach VPC Interface Endpoints"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "vpc-endpoints-sg" }
}

resource "aws_security_group_rule" "vpc_endpoints_ingress" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpc_endpoints_sg.id
  source_security_group_id = aws_security_group.eks_nodes_sg.id
  description              = "Allow HTTPS from EKS nodes to endpoints"
}

# -----------------------------
# Interface Endpoints
# -----------------------------

# locals {
#   interface_endpoints = [
#     "com.amazonaws.${var.region}.eks",
#     "com.amazonaws.${var.region}.ec2",
#     "com.amazonaws.${var.region}.sts",
#     "com.amazonaws.${var.region}.ecr.api",
#     "com.amazonaws.${var.region}.ecr.dkr",
#     "com.amazonaws.${var.region}.logs",
#     "com.amazonaws.${var.region}.ssm",
#     "com.amazonaws.${var.region}.ssmmessages"
#   ]

#   gateway_endpoints = [
#     "com.amazonaws.${var.region}.s3",
#     "com.amazonaws.${var.region}.dynamodb"
#   ]
# }

# resource "aws_vpc_endpoint" "interface" {
#   for_each            = toset(local.interface_endpoints)
#   vpc_id              = var.vpc_id
#   service_name        = each.value
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = var.eks_subnet_ids
#   security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
#   private_dns_enabled = true

#   tags = { Name = "endpoint-${each.value}" }
# }

# # -----------------------------
# # Gateway Endpoints
# # -----------------------------
# resource "aws_vpc_endpoint" "gateway" {
#   for_each          = toset(local.gateway_endpoints)
#   vpc_id            = var.vpc_id
#   service_name      = each.value
#   vpc_endpoint_type = "Gateway"
#   route_table_ids   = [var.route_private]

#   tags = { Name = "endpoint-${each.value}" }
# }
