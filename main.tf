provider "aws" {
  region = "eu-north-1"
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "my_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true
}

resource "aws_instance" "web_instance" {
  ami             = "ami-0d0b75c8c47ed0edf"
  instance_type   = "t3.micro"
  subnet_id       = aws_subnet.my_subnet.id
  tags = {
    Name         = "web-instance"
    ChaosMonkey  = "enabled"
  }
}


resource "aws_launch_configuration" "web_server_launch_config" {
  name = "web-server-launch-config"
  image_id = aws_instance.web_instance.ami
  instance_type = "t3.micro"

  lifecycle {
    create_before_destroy = true
  }
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

output "ec2_instance_private_ip" {
  value = aws_instance.web_instance.private_ip
}
