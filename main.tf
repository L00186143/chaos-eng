provider "aws" {
  region = "eu-north-1"
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}


resource "aws_security_group_rule" "allow_ssh" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sec_test.id
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
  }
}

resource "aws_launch_configuration" "web_server_launch_config" {
  name = "my-launch-config"
  image_id = aws_instance.web_instance.ami
  instance_type = "t3.micro"
  enable_monitoring = true
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


#Add Dashboard

resource "aws_cloudwatch_dashboard" "ec2_dashboard" {
  dashboard_name = "EC2-Overview"

  dashboard_body = <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "${aws_autoscaling_group.web_server_asg.name}", { "period": 300 }],
          [".", "StatusCheckFailed", ".", ".", { "stat": "Maximum", "period": 300 }]
        ],
        "view": "timeSeries",
        "stacked": false,
        "title": "CPU Utilization and Status Checks",
        "region": "eu-north-1",
        "stat": "Average",
        "period": 300
      }
    },
    {
      "type": "text",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 3,
      "properties": {
        "markdown": "## Instance Termination Events\\nMonitor termination events for EC2 instances. Set up alerts or logs for terminated instances to be displayed here."
      }
    }
  ]
}
EOF
}



# Simplify the SNS Topic setup and policy for event notifications
resource "aws_sns_topic" "my_sns_topic" {
  name = "my-sns-topic"
}

resource "aws_sns_topic_subscription" "my_email_subscription" {
  topic_arn = aws_sns_topic.my_sns_topic.arn
  protocol  = "email"
  endpoint  = "stereyno@gmail.com"
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    actions   = ["SNS:Publish"]
    effect    = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    resources  = [aws_sns_topic.my_sns_topic.arn]
  }
}

resource "aws_sns_topic_policy" "sns_topic_policy" {
  arn    = aws_sns_topic.my_sns_topic.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}


# Setup CloudWatch Event Rule for instance termination monitoring
resource "aws_cloudwatch_event_rule" "instance_termination" {
  name        = "instance-termination"
  description = "Capture EC2 instance terminations"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["terminated", "shutting-down"]
    }
  })
}

resource "aws_cloudwatch_event_target" "sns_on_termination" {
  rule      = aws_cloudwatch_event_rule.instance_termination.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.my_sns_topic.arn
}


output "sns_topic_arn" {
  value = aws_sns_topic.my_sns_topic.arn
}

output "instance_termination_rule_arn" {
  value = aws_cloudwatch_event_rule.instance_termination.arn
}


output "ec2_instance_public_ip" {
  value = aws_instance.web_instance.public_ip
}



output "ec2_instance_private_ip" {
  value = aws_instance.web_instance.private_ip
}


output "autoscaling_group_name" {
  value = aws_autoscaling_group.web_server_asg.name
}