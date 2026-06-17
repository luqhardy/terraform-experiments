terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ------------------------------------------------------
# 1. VPC & INTERNET GATEWAY
# ------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "Main-VPC" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "Main-IGW" }
}

# ------------------------------------------------------
# 2. SUBNETS
# ------------------------------------------------------
# Public Subnet 1 (AZ: a)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "Public-Subnet-1" }
}

# Public Subnet 2 (AZ: b) - Required by ALB
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags                    = { Name = "Public-Subnet-2" }
}

# Private Subnet (AZ: a) - Where your EC2 lives
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "Private-Subnet-1" }
}

# ------------------------------------------------------
# 3. ROUTING
# ------------------------------------------------------
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_1_assoc" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2_assoc" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

# ------------------------------------------------------
# 4. SECURITY GROUPS
# ------------------------------------------------------
# ALB Security Group: Allows HTTP traffic from anywhere
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP inbound traffic to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Security Group: ONLY allows HTTP traffic from the ALB
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "Allow HTTP inbound traffic from ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------------------------
# 5. EC2 INSTANCE (Private Subnet)
# ------------------------------------------------------
# Fetch the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "private_server" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_1.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  # A simple script to start a web server so the ALB has something to connect to
  user_data = <<-EOF
              #!/bin/bash
              echo "<h1>Hello from the Private Subnet!</h1>" > index.html
              nohup python3 -m http.server 80 &
              EOF

  tags = { Name = "Private-t3-micro" }
}

# ------------------------------------------------------
# 6. APPLICATION LOAD BALANCER (Public Subnets)
# ------------------------------------------------------
resource "aws_lb" "app_alb" {
  name               = "public-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_target_group_attachment" "app_tg_attach" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.private_server.id
  port             = 80
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# ------------------------------------------------------
# 7. OUTPUTS
# ------------------------------------------------------
output "load_balancer_url" {
  description = "Paste this URL into your browser to hit the private EC2 instance"
  value       = "http://${aws_lb.app_alb.dns_name}"
}


#provider "aws" {
#	region = ""
#	access_key = ""
#	secret_key = ""
#}
#
#resource "aws_ec2" "name" {
#	key1 = "value1"
#	key2 = "value2"
#
#}
# ------------------------------------------------------
# OPTIONAL: NAT GATEWAY (Commented out to prevent charges)
# Uncomment this section if your private EC2 instance needs
# outbound internet access (e.g., to run yum update).
# Note: AWS charges an hourly rate for NAT Gateways.
# ------------------------------------------------------

/*
# 1. Create an Elastic IP for the NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags   = { Name = "NAT-EIP" }
}

# 2. Create the NAT Gateway in one of the Public Subnets
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1.id
  tags          = { Name = "Main-NAT-GW" }

  # Ensures the IGW exists before creating the NAT Gateway
  depends_on = [aws_internet_gateway.igw]
}

# 3. Create a Route Table for the Private Subnet
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = { Name = "Private-Route-Table" }
}

# 4. Associate the Private Route Table with your Private Subnet
resource "aws_route_table_association" "private_1_assoc" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}
*/
