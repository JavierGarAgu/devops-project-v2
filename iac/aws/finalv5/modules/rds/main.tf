# -----------------------
# RDS Instance (Postgres example)
# -----------------------
resource "aws_db_instance" "postgres" {
  identifier                   = "private-project-db"
  allocated_storage            = 20
  storage_type                 = "gp2"
  engine                       = "postgres"
  engine_version               = "14.18"
  instance_class               = "db.t3.micro"
  username                     = "jga"   # or use random_string
  manage_master_user_password  = true       # stores password in Secrets Manager
  publicly_accessible          = false
  skip_final_snapshot          = true
  deletion_protection          = false

  vpc_security_group_ids       = [aws_security_group.rds_sg.id]
  db_subnet_group_name         = aws_db_subnet_group.private.name

  tags = {
    Name = "private-project-db"
  }
}

# -----------------------
# RDS Security Group
# -----------------------
# -----------------------------
# Null resource to fetch Node Group SG (Windows PowerShell)
# -----------------------------
resource "null_resource" "fetch_node_group_sg" {
  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]

    command = <<EOT
$NG_NAME = "${aws_eks_node_group.private_ng.node_group_name}"
$CLUSTER_NAME = "${aws_eks_cluster.this.name}"
$REGION = "eu-north-1"

# Fetch the Auto Scaling Group associated with Node Group
$ASG_NAME = (aws eks describe-nodegroup `
    --cluster-name $CLUSTER_NAME `
    --nodegroup-name $NG_NAME `
    --region $REGION `
    --query 'nodegroup.resources.autoScalingGroups[0].name' `
    --output text)

# Fetch the SGs attached to the ASG
$SG_ID = ""
for ($i = 0; $i -lt 10; $i++) {
    $instance = aws autoscaling describe-auto-scaling-groups `
        --auto-scaling-group-names $ASG_NAME `
        --region $REGION `
        --query 'AutoScalingGroups[0].Instances[0].InstanceId' `
        --output text
    if ($instance -ne "None") {
        $SG_ID = (aws ec2 describe-instances `
            --instance-ids $instance `
            --region $REGION `
            --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' `
            --output text)
        break
    } else {
        Start-Sleep -Seconds 15
    }
}
if ($SG_ID -eq "") { exit 1 }
Set-Content -Path node_group_sg.txt -Value $SG_ID

EOT
  }

  depends_on = [
    aws_eks_node_group.private_ng
  ]
}

# -----------------------------
# Data source to read SG id
# -----------------------------
data "local_file" "node_group_sg" {
  filename = "${path.module}/node_group_sg.txt"

  depends_on = [
    null_resource.fetch_node_group_sg
  ]
}

# -----------------------------
# Use the Node Group SG for RDS
# -----------------------------
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow EKS worker nodes to access RDS"
  vpc_id      = aws_vpc.project.id

  ingress {
    description     = "Postgres from EKS worker nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks     = []
    security_groups = [trimspace(data.local_file.node_group_sg.content)]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}
