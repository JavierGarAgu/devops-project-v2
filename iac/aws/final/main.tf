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
  region = "eu-north-1"
}

data "aws_ami" "example" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "architecture"
    values = ["arm64"]
  }
  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "tf-generated-key"
  public_key = tls_private_key.example.public_key_openssh
}

resource "aws_security_group" "allow_ssh" {
  name_prefix = "allow-ssh"
  vpc_id      = aws_vpc.vm_vpc.id

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

  tags = {
    Name = "ssh-access"
  }
}

resource "aws_security_group" "vm_all_traffic_from_eks" {
  name        = "vm-all-from-eks"
  description = "Allow all traffic from EKS VPC CIDR"
  vpc_id      = aws_vpc.vm_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
}

resource "aws_security_group" "eks_all_traffic_from_vm" {
  name        = "eks-all-from-vm"
  description = "Allow all traffic from VM VPC CIDR"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.vm_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.vm_vpc.cidr_block]
  }
}

resource "aws_vpc" "vm_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "vm-vpc"
  }
}

resource "aws_subnet" "vm_subnet" {
  vpc_id                  = aws_vpc.vm_vpc.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "vm-subnet"
  }
}

resource "aws_internet_gateway" "vm_igw" {
  vpc_id = aws_vpc.vm_vpc.id
  tags = {
    Name = "vm-igw"
  }
}

resource "aws_route_table" "vm_rt" {
  vpc_id = aws_vpc.vm_vpc.id
  tags = {
    Name = "vm-rt"
  }
}

resource "aws_route" "vm_internet_access" {
  route_table_id         = aws_route_table.vm_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.vm_igw.id
}

resource "aws_route_table_association" "vm_assoc" {
  subnet_id      = aws_subnet.vm_subnet.id
  route_table_id = aws_route_table.vm_rt.id
}

resource "aws_vpc_peering_connection_options" "eks_to_vm_options" {
  vpc_peering_connection_id = aws_vpc_peering_connection.eks_to_vm.id

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_instance" "example" {
  ami                         = data.aws_ami.example.id
  instance_type               = "t4g.nano"
  key_name                    = aws_key_pair.generated_key.key_name
  vpc_security_group_ids      = [
    aws_security_group.allow_ssh.id,
    aws_security_group.vm_all_traffic_from_eks.id
  ]
  subnet_id                   = aws_subnet.vm_subnet.id
  associate_public_ip_address = true

  user_data = file("setup.sh")

  tags = {
    Name = "test-spot"
  }
}

# testing
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "eks-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "eks-igw"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true
  tags = {
    Name                              = "eks-public-subnet-a"
    "kubernetes.io/role/elb"          = "1"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.20.0/24"
  availability_zone       = "eu-north-1b"
  map_public_ip_on_launch = true
  tags = {
    Name                              = "eks-public-subnet-b"
    "kubernetes.io/role/elb"          = "1"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "eks-public-rt"
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_vpc_peering_connection" "eks_to_vm" {
  vpc_id      = aws_vpc.main.id
  peer_vpc_id = aws_vpc.vm_vpc.id
  auto_accept = true

  tags = {
    Name = "eks-vpc-to-vm-vpc"
  }
}

resource "aws_route" "eks_to_vm_route" {
  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = aws_vpc.vm_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.eks_to_vm.id
}

resource "aws_route" "vm_to_eks_route" {
  route_table_id            = aws_route_table.vm_rt.id
  destination_cidr_block    = aws_vpc.main.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.eks_to_vm.id
}

resource "aws_iam_role" "eks_cluster" {
  name = "eksClusterRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "eks" {
  name     = "cheap-eks"
  role_arn = aws_iam_role.eks_cluster.arn

  depends_on = [aws_instance.example]

  version = "1.29"

  vpc_config {
    subnet_ids              = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs = ["${aws_instance.example.public_ip}/32"]
  }
}

resource "aws_iam_role" "node_group_role" {
  name = "eksNodeGroupRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "worker_node" {
  role       = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_eks_node_group" "example" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "cheap-nodes"
  node_role_arn   = aws_iam_role.node_group_role.arn
  subnet_ids      = [aws_subnet.public_a.id]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  instance_types = ["t4g.micro"]
  capacity_type  = "SPOT"
  ami_type       = "AL2_ARM_64"
}

output "private_key_pem" {
  value     = tls_private_key.example.private_key_pem
  sensitive = true
}

output "public_ip" {
  value = aws_instance.example.public_ip
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks.endpoint
}

output "cluster_name" {
  value = aws_eks_cluster.eks.name
}
