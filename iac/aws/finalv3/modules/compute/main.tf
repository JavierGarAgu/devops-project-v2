data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }
}

resource "aws_instance" "jumpbox" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t4g.nano"
  subnet_id                   = var.eks_subnet_id
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [var.jumpbox_sg_id]
  associate_public_ip_address = false
  iam_instance_profile        = var.iam_instance_profile
  tags = { Name = "eks-jumpbox" }
}

resource "aws_instance" "admin" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t4g.nano"
  subnet_id                   = var.admin_subnet_id
  key_name                    = var.key_pair_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [var.ssh_sg_id]

  user_data = templatefile(var.admin_vm_script, {
    private_key = var.private_key_pem,
    jumpbox_ip  = aws_instance.jumpbox.private_ip,
    phostname = var.phostname,
    rds_arn = var.rds_arn
  })

  provisioner "file" {
    source      = var.rpms_file
    destination = "/home/ec2-user/rpms.tar.gz"
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = var.private_key_pem
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = var.jumpbox_setup_file
    destination = "/home/ec2-user/setup_jumpbox.sh"
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = var.private_key_pem
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = var.sql_file
    destination = "/home/ec2-user/init.sql"
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = var.private_key_pem
      host        = self.public_ip
    }
  }

  tags = { Name = "admin-vm" }

  depends_on = [aws_instance.jumpbox]
}
