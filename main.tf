/*provider "aws" {
  region     = "us-east-1"
  access_key = ""
  secret_key = ""
}
resource "time_sleep" "wait" {
  create_duration = "300s"
}*/

resource "aws_vpc" "prod-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = "true"
  enable_dns_support   = "true"
  instance_tenancy     = "default"

  tags = {
    Name = "prod_vpc"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.prod-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = "us-east-1a"
  tags = {
    Name = "public_subnet_1"
  }
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.prod-vpc.id
  tags = {
    Name = "prod_internet_gateway"
  }
}

resource "aws_route_table" "prod-public-route" {
  vpc_id = aws_vpc.prod-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
  tags = {
    Name = "public_route_table"
  }
}

resource "aws_route_table_association" "subnet-assoc" {
  route_table_id = aws_route_table.prod-public-route.id
  subnet_id      = aws_subnet.public_subnet_1.id

}

resource "aws_security_group" "my_sg" {
  vpc_id = aws_vpc.prod-vpc.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "My_security_group"
  }
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "TF" {
  key_name   = "TF"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "local_file" "TFF" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "TF_KEY"
}

resource "aws_instance" "my_ec2" {
  instance_type   = "t2.micro"
  ami             = "ami-0b0dcb5067f052a63"
  subnet_id       = aws_subnet.public_subnet_1.id
  vpc_security_group_ids = [aws_security_group.my_sg.id]
  key_name        = "TF"
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = tls_private_key.rsa.private_key_pem
    host        = aws_instance.my_ec2.public_ip
  }
user_data = filebase64("${path.module}/kubesetup.sh")
/*
  user_data = <<EOF
#!/bin/bash
sudo yum install httpd  php git -y
sudo echo HI this is soma > /var/www/html/index.html
sudo systemctl restart httpd
sudo systemctl enable httpd
EOF
*/
/*  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo echo HI this is soma > /var/www/html/index.html"
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
  */
  tags = {
    Name = "redhat_webserver_terr"
  }
}

output "instance_ip_addr" {
  value = aws_instance.my_ec2.public_ip
}
