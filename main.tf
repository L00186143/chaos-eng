provider "aws" {
  region = "eu-north-1"
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

resource "aws_security_group" "sec_test" {
  name        = "test-security-group"
  description = "Security group for chaos engineering test"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["80.233.50.251/32"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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
    Name = "sec_test"
  }
}


resource "aws_subnet" "my_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true
}


resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}

resource "aws_route_table_association" "my_route_table_assoc" {
  subnet_id      = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.my_route_table.id
}



resource "aws_instance" "web_instance" {
  ami             = "ami-0d0b75c8c47ed0edf"
  instance_type   = "t3.micro"
  key_name        = "tfchaos"
  vpc_security_group_ids = [aws_security_group.sec_test.id]
  subnet_id       = aws_subnet.my_subnet.id
  tags = {
    Name         = "web-instance"
    ChaosMonkey  = "enabled"
  }
}


resource "aws_launch_configuration" "web_server_launch_config" {
  name = "my-launch-config"
  image_id = aws_instance.web_instance.ami
  instance_type = "t3.micro"
}

resource "aws_autoscaling_group" "web_server_asg" {
  desired_capacity     = 1
  max_size             = 4
  min_size             = 1

  launch_configuration = aws_launch_configuration.web_server_launch_config.id

  vpc_zone_identifier = [aws_subnet.my_subnet.id]

  health_check_type          = "EC2"
  health_check_grace_period  = 300
}


terraform {
  backend "s3" {
    bucket = "tfstate-atu"
    key    = "terraform.tfstate"
    region = "eu-north-1"
    encrypt = true
  }
}


output "ec2_instance_private_ip" {
  value = aws_instance.web_instance.private_ip
}


output "autoscaling_group_name" {
  value = aws_autoscaling_group.web_server_asg.name
}