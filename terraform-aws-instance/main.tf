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
}

resource "aws_instance" "app_server" {
  ami           = "ami-045a8ab02aadf4f88"
  instance_type = "t3.micro"

  tags = {
    Name = "loki"
  }
}

resource "random_pet" "bucket_name" {
  length    = 5
  separator = "-"
  prefix    = "learning"
}

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

resource "aws_lb_target_group" "loki_tg" { 
 name     = "target-group_loki"
 port     = 80
 protocol = "HTTP"
}

resource "aws_lb_target_group_attachment" "tg_attachment" {
 target_group_arn = aws_lb_target_group.my_tg.arn
 target_id        = aws_instance.instance.id
 port             = 80
}

resource "aws_lb" "loki_lb" {
 name               = "loki_lb"
 internal           = false
 load_balancer_type = "application"
 # subnets = ["subnet-"]
 
 tags = {
   Environment = "dev"
 }
}

resource "aws_lb_listener" "loki_listener" {
 load_balancer_arn = aws_lb.loki_lb
 port              = "80"
 protocol          = "HTTP"

 default_action {
   type             = "forward"
   target_group_arn = aws_lb_target_group.loki_tg_a.arn
 }
}

