# -----------------------------
# Availability Zones
# -----------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_availability_zones" "db" {
  state = "available"
}

# -----------------------------
# VPC
# -----------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "main-vpc" }
}

# -----------------------------
# Internet Gateway (for NAT)
# -----------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "main-igw" }
}

# -----------------------------
# Public subnet for NAT Gateway / Admin
# -----------------------------
resource "aws_subnet" "admin" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = { Name = "admin-subnet" }
}

# -----------------------------
# Private EKS subnets
# -----------------------------
resource "aws_subnet" "eks_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false
  tags = {
    Name                                      = "eks-subnet-a"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "eks_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch = false
  tags = {
    Name                                      = "eks-subnet-b"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# -----------------------------
# Private DB subnets
# -----------------------------
resource "aws_subnet" "db_subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.db.names[0]
  tags                     = { Name = "db-subnet-a" }
}

resource "aws_subnet" "db_subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.5.0/24"
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.db.names[1]
  tags                     = { Name = "db-subnet-b" }
}

# -----------------------------
# Public route table (for admin / NAT subnet)
# -----------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "admin" {
  subnet_id      = aws_subnet.admin.id
  route_table_id = aws_route_table.public.id
}

# -----------------------------
# NAT Gateway
# -----------------------------
resource "aws_eip" "nat" {
  domain = "vpc"  # replaces vpc = true
  tags   = { Name = "nat-eip" }
}


resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.admin.id
  depends_on    = [aws_internet_gateway.igw]
  tags          = { Name = "main-nat" }
}

# -----------------------------
# Private route table for EKS and DB subnets
# -----------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "private-rt" }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
  depends_on             = [aws_nat_gateway.nat]
}

resource "aws_route_table_association" "eks_a" {
  subnet_id      = aws_subnet.eks_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "eks_b" {
  subnet_id      = aws_subnet.eks_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db_subnet_a" {
  subnet_id      = aws_subnet.db_subnet_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db_subnet_b" {
  subnet_id      = aws_subnet.db_subnet_b.id
  route_table_id = aws_route_table.private.id
}
