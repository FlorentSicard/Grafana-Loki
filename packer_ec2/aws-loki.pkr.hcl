packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name = "${var.ami_prefix}-${local.timstamp}"
  AWS_ACCESS_KEY_ID="${var.access_key}"
  AWS_SECRET_ACCESS_KEY="${var.secret_key}"
  instance_type = "t3.micro"
  region        = "eu-west-3"
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "loki"
}

build {
  name = "${var.ami_prefix}-${local.timstamp}"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

  provisioner "shell" {
    inline = [
        "sudo apt-get update"
    ]
}
}

