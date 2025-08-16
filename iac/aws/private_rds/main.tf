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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

# ─────────────────────────────────────────────
# Data sources
data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# Amazon Linux 2023 (ARM64) for t4g.*
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }
}

# ─────────────────────────────────────────────
# Random (username only; password managed by RDS/Secrets Manager)
resource "random_string" "db_master_username" {
  length  = 15     # 1 char will be added as prefix to ensure AWS validity
  upper   = false
  lower   = true
  numeric = true   # <- fixed: replaced deprecated "number" with "numeric"
  special = false
}

locals {
  db_master_username = "u${random_string.db_master_username.result}"
}

# ─────────────────────────────────────────────
# Key pairs for Admin & Jumpbox
resource "tls_private_key" "admin_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "admin_key_pair" {
  key_name   = "terraform-admin-key"
  public_key = tls_private_key.admin_key.public_key_openssh
}

resource "tls_private_key" "jumpbox_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "jumpbox_key_pair" {
  key_name   = "terraform-jumpbox-key"
  public_key = tls_private_key.jumpbox_key.public_key_openssh
}

# ─────────────────────────────────────────────
# VPC & Networking
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "main-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "main-igw" }
}

# Public subnet (admin VM)
resource "aws_subnet" "admin_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = { Name = "admin-subnet" }
}

# Private subnets (jumpbox + DB)
resource "aws_subnet" "jumpbox_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[1]
  tags = { Name = "jumpbox-subnet" }
}

# DB needs a subnet group with at least 2 subnets in different AZs
resource "aws_subnet" "db_subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = { Name = "db-subnet-a" }
}

resource "aws_subnet" "db_subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[1]
  tags = { Name = "db-subnet-b" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "admin_assoc" {
  subnet_id      = aws_subnet.admin_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# ─────────────────────────────────────────────
# Security Groups
resource "aws_security_group" "ssh_allow_all" {
  name        = "allow-ssh"
  description = "Allow SSH inbound to admin VM"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "allow-ssh" }
}

resource "aws_security_group" "jumpbox_sg" {
  name        = "jumpbox-sg"
  description = "Allow SSH from admin subnet; egress for VPC endpoints/DB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"] # Admin subnet
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "jumpbox-sg" }
}

resource "aws_security_group" "db_sg" {
  name        = "private-db-sg"
  description = "Allow Postgres only from Jumpbox SG"
  vpc_id      = aws_vpc.main.id

  # No inline ingress; add a separate rule scoped to the jumpbox SG below
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "private-db-sg" }
}

resource "aws_security_group_rule" "db_ingress_from_jumpbox" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db_sg.id
  source_security_group_id = aws_security_group.jumpbox_sg.id
  description              = "Postgres from jumpbox"
}

# SG for VPC endpoints (HTTPS from VPC)
resource "aws_security_group" "vpce_https_sg" {
  name        = "vpce-https-sg"
  description = "Allow HTTPS from VPC to Interface Endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "vpce-https-sg" }
}

# ─────────────────────────────────────────────
# IAM Role for Jumpbox to read only the DB master secret
resource "aws_iam_role" "jumpbox_rds_role" {
  name = "jumpbox-secrets-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach policy after the DB exists so we can scope to its secret ARN
data "aws_iam_policy_document" "jumpbox_secrets_doc" {
  statement {
    sid     = "AllowGetDbMasterSecret"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [
      aws_db_instance.private_postgres.master_user_secret[0].secret_arn
    ]
  }
}

resource "aws_iam_policy" "jumpbox_secrets_policy" {
  name        = "jumpbox-secrets-get-policy"
  description = "Allow jumpbox to read the RDS master secret only"
  policy      = data.aws_iam_policy_document.jumpbox_secrets_doc.json
}

resource "aws_iam_role_policy_attachment" "jumpbox_secrets_attach" {
  role       = aws_iam_role.jumpbox_rds_role.name
  policy_arn = aws_iam_policy.jumpbox_secrets_policy.arn
}

resource "aws_iam_instance_profile" "jumpbox_rds_profile" {
  name = "jumpbox-secrets-profile"
  role = aws_iam_role.jumpbox_rds_role.name
}

# ─────────────────────────────────────────────
# Private RDS Instance (NO hardcoded password)
resource "aws_db_subnet_group" "private_db_subnet_group" {
  name       = "private-db-subnet-group"
  subnet_ids = [aws_subnet.db_subnet_a.id, aws_subnet.db_subnet_b.id]
  tags       = { Name = "private-db-subnet-group" }
}

resource "aws_db_instance" "private_postgres" {
  identifier                   = "private-project-db"
  allocated_storage            = 20
  storage_type                 = "gp2"
  engine                       = "postgres"
  engine_version               = "14.18"
  instance_class               = "db.t3.micro"
  username                     = local.db_master_username
  manage_master_user_password  = true
  publicly_accessible          = false
  skip_final_snapshot          = true
  deletion_protection          = false
  vpc_security_group_ids       = [aws_security_group.db_sg.id]
  db_subnet_group_name         = aws_db_subnet_group.private_db_subnet_group.name
  tags = { Name = "private-project-db" }
}

# ─────────────────────────────────────────────
# EC2 Instances
resource "aws_instance" "admin_vm" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t4g.nano"
  key_name                    = aws_key_pair.admin_key_pair.key_name
  subnet_id                   = aws_subnet.admin_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ssh_allow_all.id]

  # Pass Jumpbox private key & IP to bootstrap script
  user_data = templatefile("${path.module}/setup_admin.sh", {
    private_key = tls_private_key.jumpbox_key.private_key_pem,
    jumpbox_ip  = aws_instance.jumpbox.private_ip,
    phostname = aws_db_instance.private_postgres.address,
    rds_arn = aws_db_instance.private_postgres.master_user_secret[0].secret_arn
  })

  # Copy jumpbox setup script
  provisioner "file" {
    source      = "${path.module}/setup_jumpbox.sh"
    destination = "/home/ec2-user/setup_jumpbox.sh"
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = tls_private_key.admin_key.private_key_pem
      host        = self.public_ip
    }
  }

  # Copy admin setup script
  provisioner "file" {
    source      = "${path.module}/setup_admin.sh"
    destination = "/home/ec2-user/setup_admin.sh"
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = tls_private_key.admin_key.private_key_pem
      host        = self.public_ip
    }
  }

  # Copy packaged files (RPMs, etc.)
  provisioner "file" {
    source      = "${path.module}/bin/rpms.tar.gz"
    destination = "/home/ec2-user/rpms.tar.gz"
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = tls_private_key.admin_key.private_key_pem
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = "${path.module}/bin/init.sql"
    destination = "/home/ec2-user/init.sql"
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = tls_private_key.admin_key.private_key_pem
      host        = self.public_ip
    }
  }

  tags = { Name = "admin-vm" }

  depends_on = [aws_instance.jumpbox]
}

resource "aws_instance" "jumpbox" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t4g.nano"
  key_name                    = aws_key_pair.jumpbox_key_pair.key_name
  subnet_id                   = aws_subnet.jumpbox_subnet.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.jumpbox_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.jumpbox_rds_profile.name
  tags = { Name = "jumpbox" }

  depends_on = [aws_db_instance.private_postgres]

}

# ─────────────────────────────────────────────
locals {
  interface_services = [
    "sts",
    "kms",
    "secretsmanager"
  ]
}

resource "aws_vpc_endpoint" "interface_endpoints" {
  for_each = toset(local.interface_services)

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.jumpbox_subnet.id]
  security_group_ids  = [aws_security_group.vpce_https_sg.id]
  private_dns_enabled = true
  tags = {
    Name = "vpce-${each.key}"
  }
}

# ─────────────────────────────────────────────
# Outputs
output "admin_vm_public_ip" {
  value = aws_instance.admin_vm.public_ip
}

output "jumpbox_private_ip" {
  value = aws_instance.jumpbox.private_ip
}

output "admin_private_key_pem" {
  value     = tls_private_key.admin_key.private_key_pem
  sensitive = true
}

output "jumpbox_private_key_pem" {
  value     = tls_private_key.jumpbox_key.private_key_pem
  sensitive = true
}

output "private_postgres_endpoint" {
  value = aws_db_instance.private_postgres.address
}

output "private_postgres_port" {
  value = aws_db_instance.private_postgres.port
}

output "private_postgres_master_username" {
  description = "Randomly generated master username (password is in Secrets Manager)"
  value       = aws_db_instance.private_postgres.username
}

output "private_postgres_master_secret_arn" {
  description = "Secrets Manager ARN that stores the managed master password"
  value       = aws_db_instance.private_postgres.master_user_secret[0].secret_arn
}
