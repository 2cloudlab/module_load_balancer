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
  template = file("${path.module}/service.sh")
  vars = {
    server_port = local.server_port
  }
}

locals {
  server_port                 = 80
  count_of_availability_zones = length(data.aws_availability_zones.available.names)
}

resource "aws_security_group" "alb" {
  name = "sg_for_alb"

  # Allow inbound HTTP requests
  ingress {
    from_port   = local.server_port
    to_port     = local.server_port
    protocol    = "tcp"
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
  image_id      = "ami-0278fe6949f6b1a06"
  instance_type = "t2.micro"
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "asg_flag"
    }
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

###################### Output ######################################

output "alb_dns_name" {
  value       = aws_lb.alb.dns_name
  description = "The domain name of the load balancer"
}