provider "aws" {
  region = "eu-north-1"
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  # CloudWatch Logs Agent configuration within the VPC
  tags = {
    Name = "my-vpc"
    CloudWatchLogsAgent = "enabled" # Flag indicating VPC is monitored
  }
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


resource "aws_cloudwatch_metric_alarm" "low_instance_count" {
  alarm_name                = "low-instance-count"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = "2"
  metric_name               = "GroupTotalInstances"
  namespace                 = "AWS/AutoScaling"
  period                    = "60"
  statistic                 = "Average"
  threshold                 = "1"  # Set based on your minimum instance count
  alarm_description         = "This metric monitors the total instance count in the ASG"
  alarm_actions             = ["arn:aws:sns:eu-north-1:123456789012:my-sns-topic"]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_server_asg.name
  }
}


resource "aws_cloudwatch_log_group" "instance_logs" {
  name = "/aws/instance/logs"
  retention_in_days = 14
}


resource "aws_cloudwatch_event_rule" "autoscaling_events" {
  name        = "autoscaling-events"
  description = "Capture autoscaling events"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.autoscaling"
  ],
  "detail-type": [
    "EC2 Instance-launch Lifecycle Action",
    "EC2 Instance-terminate Lifecycle Action"
  ]
}
PATTERN
}

resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.autoscaling_events.name
  arn  = aws_sns_topic.my_sns_topic.arn
}

resource "aws_sns_topic" "my_sns_topic" {
  name = "my-sns-topic"
}


resource "aws_sns_topic_subscription" "my_email_subscription" {
  topic_arn = aws_sns_topic.my_sns_topic.arn
  protocol  = "email"
  endpoint  = "stereyno@gmail.com"
}



resource "aws_sns_topic_policy" "sns_topic_policy" {
  arn    = aws_sns_topic.my_sns_topic.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}


resource "aws_cloudwatch_dashboard" "chaos_dashboard" {
  dashboard_name = "ChaosDashboard"

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
          ["AWS/EC2", "CPUUtilization", "InstanceId", "aws_instance.web_instance.id"]
        ],
        "period": 300,
        "stat": "Average",
        "region": "eu-north-1",
        "title": "EC2 Instance CPU Utilization"
      }
    }
  ]
}
EOF
}




terraform {
  backend "s3" {
    bucket = "tfstate-atu"
    key    = "terraform.tfstate"
    region = "eu-north-1"
    encrypt = true
  }
}



data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    actions = [
      "SNS:Publish",
      "SNS:RemovePermission",
      "SNS:SetTopicAttributes",
      "SNS:DeleteTopic",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:Receive",
      "SNS:AddPermission",
      "SNS:Subscribe"
    ]

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_sns_topic.my_sns_topic.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"
      values   = ["${data.aws_caller_identity.current.account_id}"]
    }
  }
}

data "aws_caller_identity" "current" {}



output "ec2_instance_private_ip" {
  value = aws_instance.web_instance.private_ip
}


output "autoscaling_group_name" {
  value = aws_autoscaling_group.web_server_asg.name
}


output "sns_topic_arn" {
  value = aws_sns_topic.my_sns_topic.arn
}
