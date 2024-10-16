terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "eu-west-3"
  #access_key = 
  #secret_key =
}

#EC2
resource "aws_instance" "loki" {
  ami           = "ami-045a8ab02aadf4f88"
  instance_type = "t3.micro"
  subnet_id = aws_subnet.public_subnet.id
  associate_public_ip_address = true 
  security_groups = [aws_security_group.lb_sg.id]

  tags = {
    Name = "loki"
  }
}

#attachment instance -> target group
resource "aws_lb_target_group_attachment" "target-group_loki" {
  target_group_arn = aws_lb_target_group.loki_tg.arn
  target_id = aws_instance.app_instance.id
  port = 80
}

#VPC
resource "aws_vpc" "loki_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true 
  tags = {
    Name = "loki_vpc"
  }
}

#subnet
resource "aws_subnet" "loki_subnet" {
  vpc_id = aws_vpc.loki_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-3"
  map_public_ip_on_launch = true
  tags = {
    Name = "loki_subnet"
  }
}

#bucket s3 name
resource "random_pet" "bucket_name" {
  length    = 5
  separator = "-"
  prefix    = "learning"
}

#Bucket s3
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.1.1"

  bucket = random_pet.bucket_name.id
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

#target group
resource "aws_lb_target_group" "loki_tg" { 
 name     = "target-group_loki"
 port     = 80
 protocol = "HTTP"
 vpc_id = aws_vpc.main_vpc.id

 health_check {
   healthy_threshold = 2
   unhealthy_threshold = 2
   timeout = 5
   path = "/"
   interval = 30
   protocol = "HTTP"
 }

 tags = {
   Name = "loki_tg"
 }
}

# target group attachment -> instance
resource "aws_lb_target_group_attachment" "tg_attachment" {
 target_group_arn = aws_lb_target_group.loki_tg.arn
 target_id        = aws_instance.instance.id
 port             = 80
}

# load balancer
resource "aws_lb" "loki_lb" {
 name               = "loki_lb"
 internal           = false
 load_balancer_type = "application"
 security_groups = [aws_security_group.lb_sg]
 subnets = [aws_subnet.loki_subnet]

 tags = {
   Environment = "dev"
 }
}

#security group load balancer
resource "aws_security_group" "lb_sg" {
  vpc_id = aws_vpc.loki_vpc.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port =0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lb_sg"
  }
}

#listener load balancer
resource "aws_lb_listener" "loki_listener" {
 load_balancer_arn = aws_lb.loki_lb.arn
 port              = "80"
 protocol          = "HTTP"

 default_action {
   type             = "forward"
   target_group_arn = aws_lb_target_group.loki_tg.arn
 }
}

