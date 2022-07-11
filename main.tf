terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.22.0"
    }
  }
}

provider "aws" {
  region     = "eu-west-1"

}


#Network setup
#VPC with IGW and route table
resource "aws_vpc" "dev_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"


  tags = {
    Name = "dev_vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.dev_vpc.id

  tags = {
    Name = "main"
  }
}

resource "aws_route_table" "default_route" {
  vpc_id = aws_vpc.dev_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  depends_on = [
    aws_internet_gateway.gw
  ]
}

#Subnet setup with separate subnet for web,db and lb
resource "aws_subnet" "web_subnet" {
  vpc_id     = aws_vpc.dev_vpc.id
  cidr_block = var.web_sub_cidr
}

resource "aws_subnet" "db_subnet" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = var.db_sub_cidr
  availability_zone = "eu-west-1c"
}

resource "aws_subnet" "db_subnet_1" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = var.db_sub_cidr_1
  availability_zone = "eu-west-1b"
}

resource "aws_subnet" "lb_subnet" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = var.lb_sub_cidr
  availability_zone = "eu-west-1c"
}

resource "aws_subnet" "lb_subnet_1" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = var.lb_sub_cidr_1
  availability_zone = "eu-west-1b"
}

resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.db_subnet.id, aws_subnet.db_subnet_1.id]
}

#Security Groups

#Load balancer sec.group with open http access
resource "aws_security_group" "lb_sec_group" {
  name        = "allow_http_internet"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    description = "HTTPS/Public"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

#Web server sec.group with allowed traffic from load balancer
resource "aws_security_group" "web_server_sec_group" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    description     = "HTTPS/Load Balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sec_group.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

}


#RDS sec.group with mysql traffic from web servers
resource "aws_security_group" "db_server_sec_group" {
  name        = "allow_sql_traffic"
  description = "Allow sql inbound traffic"
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    description     = "MySQL/Web_Server"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_server_sec_group.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "MySQL Access"
  }
}


#DB Setup

resource "aws_db_instance" "rds_database" {

  allocated_storage    = var.db_allocated_storage
  instance_class       = var.db_instance
  engine               = var.db_engine
  engine_version       = var.db_engine_version
  db_name              = var.db_name
  username             = var.db_username
  password             = var.db_password
  db_subnet_group_name = aws_db_subnet_group.default.name
  #
  skip_final_snapshot = true
  
}

#EFS Setup


resource "aws_efs_file_system" "shared_filesystem" {
  tags = {
    Name = "FileStorage"
  }

  lifecycle_policy {
    transition_to_ia = "AFTER_7_DAYS"
  }
}

resource "aws_efs_file_system_policy" "policy" {
  file_system_id = aws_efs_file_system.shared_filesystem.id
  policy         = <<POLICY
{
    "Version": "2012-10-17",
    "Id": "policy01",
    "Statement": [
        {
            "Sid": "Statement",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Resource": "${aws_efs_file_system.shared_filesystem.arn}",
            "Action": [
                "elasticfilesystem:ClientMount",
                "elasticfilesystem:ClientRootAccess",
                "elasticfilesystem:ClientWrite"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        }
    ]
}
POLICY
}

resource "aws_efs_mount_target" "mount_targets" {
  file_system_id = aws_efs_file_system.shared_filesystem.id
  subnet_id      = aws_subnet.web_subnet.id
}

#WEB Setup

resource "aws_instance" "web_server" {

  instance_type               = var.web_instance
  ami                         = var.web_ami
  subnet_id                   = aws_subnet.web_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.web_server_sec_group.id]

  user_data = <<EOF
  #!/bin/bash
  wget

EOF 
 
  lifecycle {
    ignore_changes = [
      
    ]
  }
}


#Autoscale Launch configuration Setup
resource "aws_launch_configuration" "autoscale_launch_conf" {
  name          = "web_config"
  image_id      = aws_ami_from_instance.autoscale_ami.id
  instance_type = "t2.micro"

  lifecycle {
    create_before_destroy = true
  }
}



#Load Balancer 
resource "aws_lb" "load_balancer" {
  name               = "loadbalancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sec_group.id]
  subnets            = [aws_subnet.lb_subnet.id, aws_subnet.lb_subnet_1.id]

  enable_deletion_protection = false


}

#Load Balancer target group
resource "aws_lb_target_group" "http_forward" {
  name     = "httpforward"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.dev_vpc.id

}

#Load Balancer listener
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.http_forward.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group_attachment" "lb_targets" {
  target_group_arn = aws_lb_target_group.http_forward.arn
  target_id        = aws_instance.web_server.id
  port             = 80
}

#CloudWatch alarm
resource "aws_cloudwatch_metric_alarm" "lb_alarm_connections" {
  alarm_name          = "lb_alarm_connections"
  namespace           = "AWS/ApplicationELB"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  metric_name         = "ActiveConnectionCount"
  evaluation_periods  = "2"
  period              = "60"
  statistic           = "Average"
  threshold           = "10"
  alarm_description   = "Monitors if active connections are more than 10"
}