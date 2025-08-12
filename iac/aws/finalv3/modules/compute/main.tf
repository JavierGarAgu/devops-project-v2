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

user_data = <<-EOF
              #!/bin/bash
              mkdir -p /home/ec2-user/.ssh
              echo '${var.private_key_pem}' > /home/ec2-user/.ssh/jumpbox_id_rsa
              chmod 600 /home/ec2-user/.ssh/jumpbox_id_rsa
              chown ec2-user:ec2-user /home/ec2-user/.ssh/jumpbox_id_rsa

              # Export jumpbox IP as environment variable for ec2-user
              echo "export JUMPBOX_IP=${jumpbox_ip}" >> /home/ec2-user/.bash_profile
              chown ec2-user:ec2-user /home/ec2-user/.bash_profile
              EOF

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

  tags = { Name = "admin-vm" }

  depends_on = [aws_instance.jumpbox]
}
