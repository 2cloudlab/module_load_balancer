terraform {
  required_version = "= 0.12.19"
}

provider "aws" {
  version = "= 2.58"
  region = "ap-northeast-1"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "template_file" "shell" {
  template = file("${path.module}/prepare.sh")
  vars = {
    download_url = var.download_url
    package_base_dir = var.package_base_dir
    app_dir = var.app_dir
    envs = local.envs_in_seq
  }
}

variable "download_url" {
  type        = string
  default = "https://github.com/digolds/digolds_sample/archive/v0.0.1.tar.gz"
}

variable "package_base_dir" {
  type        = string
  default = "digolds_sample-0.0.1"
}

variable "app_dir" {
  type        = string
  default = "personal-blog"
}

variable "envs" {
  type        = list
  default = ["USER_NAME=slz", "PASSWORD=abc", "TABLE_NAME=personal-articles-table", "INDEX_NAME=ContentGlobalIndex"]
}

data "aws_region" "current" {}

locals {
  server_port                 = 80
  envs_in_seq = format("-e %s", join(" -e ", concat([format("AWS_DEFAULT_REGION=%s", data.aws_region.current.name)], var.envs)))
  count_of_availability_zones = length(data.aws_availability_zones.available.names)
}

resource "aws_security_group" "alb" {
  name = "sg_for_alb"

  # Allow inbound HTTP requests
  ingress {
    from_port   = local.server_port
    to_port     = local.server_port
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound requests
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_template" "vm_template" {
  name_prefix   = "template_1"
  image_id      = "ami-06a46da680048c8ae"
  instance_type = "t2.micro"
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "asg_flag"
    }
  }
  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_profile.arn
  }
  user_data              = base64encode(data.template_file.shell.rendered)
  vpc_security_group_ids = [aws_security_group.alb.id]
}

resource "aws_autoscaling_group" "example" {
  vpc_zone_identifier = data.aws_subnet_ids.default.ids

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  desired_capacity = local.count_of_availability_zones
  max_size         = local.count_of_availability_zones + 1
  min_size         = local.count_of_availability_zones

  launch_template {
    id      = aws_launch_template.vm_template.id
    version = "$Latest"
  }
}

##################### ALB Related #######################################

resource "aws_lb" "alb" {
  name               = "alb-1"
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.default.ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = local.server_port
  protocol          = "HTTP"

  # By default, return a 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_lb_target_group" "asg" {
  name     = "asg-1"
  port     = local.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.listener.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

data "aws_iam_policy_document" "instance-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "assume_role" {
  name               = "assume_role"
  path               = "/custom/"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.assume_role.name
}

resource "aws_iam_role_policy" "dynamodb_policy_all" {
  name = "dynamodb_policy_all"
  role = aws_iam_role.assume_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "dynamodb:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

###################### Output ######################################

output "alb_dns_name" {
  value       = aws_lb.alb.dns_name
  description = "The domain name of the load balancer"
}
