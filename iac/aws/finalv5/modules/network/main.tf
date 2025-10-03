# -----------------------
# Networking (VPC & Subnets)
# -----------------------

resource "aws_vpc" "project" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "project-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.project.id
  tags = {
    Name = "project-igw"
  }
}

# Public subnets
resource "aws_subnet" "public1_a" {
  vpc_id                  = aws_vpc.project.id
  cidr_block              = "10.0.0.0/20"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = false
  tags = {
    Name = "project-subnet-public1-eu-north-1a"
  }
}

resource "aws_subnet" "public2_b" {
  vpc_id                  = aws_vpc.project.id
  cidr_block              = "10.0.16.0/20"
  availability_zone       = "eu-north-1b"
  map_public_ip_on_launch = false
  tags = {
    Name = "project-subnet-public2-eu-north-1b"
  }
}

resource "aws_subnet" "public3_c" {
  vpc_id                  = aws_vpc.project.id
  cidr_block              = "10.0.32.0/20"
  availability_zone       = "eu-north-1c"
  map_public_ip_on_launch = false
  tags = {
    Name = "project-subnet-public3-eu-north-1c"
  }
}

# Private subnets
resource "aws_subnet" "private1_a" {
  vpc_id            = aws_vpc.project.id
  cidr_block        = "10.0.128.0/20"
  availability_zone = "eu-north-1a"
  tags = {
    Name = "project-subnet-private1-eu-north-1a"
  }
}

resource "aws_subnet" "private2_b" {
  vpc_id            = aws_vpc.project.id
  cidr_block        = "10.0.144.0/20"
  availability_zone = "eu-north-1b"
  tags = {
    Name = "project-subnet-private2-eu-north-1b"
  }
}

resource "aws_subnet" "private3_c" {
  vpc_id            = aws_vpc.project.id
  cidr_block        = "10.0.160.0/20"
  availability_zone = "eu-north-1c"
  tags = {
    Name = "project-subnet-private3-eu-north-1c"
  }
}

# -----------------------
# NAT & EIP
# -----------------------

resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "project-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public1_a.id
  tags = {
    Name = "project-nat-public1-eu-north-1a"
  }
  depends_on = [aws_internet_gateway.igw]
}

# -----------------------
# Route tables
# -----------------------

# Public route table with IGW route
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.project.id
  tags = {
    Name = "project-rtb-public"
  }
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate all public subnets with the public RTB
resource "aws_route_table_association" "public1_a" {
  subnet_id      = aws_subnet.public1_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2_b" {
  subnet_id      = aws_subnet.public2_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public3_c" {
  subnet_id      = aws_subnet.public3_c.id
  route_table_id = aws_route_table.public.id
}

# Private route tables (per AZ) with default route to NAT
resource "aws_route_table" "private1_a" {
  vpc_id = aws_vpc.project.id
  tags = {
    Name = "project-rtb-private1-eu-north-1a"
  }
}

resource "aws_route" "private1_nat" {
  route_table_id         = aws_route_table.private1_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private1_a" {
  subnet_id      = aws_subnet.private1_a.id
  route_table_id = aws_route_table.private1_a.id
}

resource "aws_route_table" "private2_b" {
  vpc_id = aws_vpc.project.id
  tags = {
    Name = "project-rtb-private2-eu-north-1b"
  }
}

resource "aws_route" "private2_nat" {
  route_table_id         = aws_route_table.private2_b.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private2_b" {
  subnet_id      = aws_subnet.private2_b.id
  route_table_id = aws_route_table.private2_b.id
}

resource "aws_route_table" "private3_c" {
  vpc_id = aws_vpc.project.id
  tags = {
    Name = "project-rtb-private3-eu-north-1c"
  }
}

resource "aws_route" "private3_nat" {
  route_table_id         = aws_route_table.private3_c.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private3_c" {
  subnet_id      = aws_subnet.private3_c.id
  route_table_id = aws_route_table.private3_c.id
}

# Optional: default/main route table (only local routes, as in your output)
resource "aws_default_route_table" "main" {
  default_route_table_id = aws_vpc.project.default_route_table_id
  tags = {
    Name = "project-rtb-main"
  }
}