locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "loki-${local.timestamp}"
  instance_type = "t3.small"
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
  ssh_username = "ubuntu"
}

build {
  name = "loki-${local.timestamp}"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

  provisioner "shell" {
    inline = [
      "sudo apt-get update"
    ]
  }

  # File + install Grafana
  provisioner "file" {
    source      = "../loki/config/grafana/datasources/datasources.yaml"
    destination = "/tmp/datasources.yaml"
  }

  provisioner "shell" {
    inline = [
      "sudo apt-get install -y apt-transport-https software-properties-common wget",
      "sudo mkdir -p /etc/apt/keyrings/",
      "wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null",
      "echo \"deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main\" | sudo tee -a /etc/apt/sources.list.d/grafana.list",
      "sudo apt-get update",
      "sudo apt-get install -y grafana",
      "sudo mv /tmp/datasources.yaml /etc/grafana/provisioning/datasources/datasources.yaml",
    ]
  }

    # File + install Loki
  provisioner "file" {
    source      = "../loki/config/loki/loki.yaml"
    destination = "/tmp/loki.yaml"
  }

  provisioner "shell" {
    inline = [
      "sudo apt-get install loki",
      "sudo mv /tmp/loki.yaml /etc/loki/local-config.yaml",
    ]
  }

  # File + install Nginx
  provisioner "file" {
    source      = "../loki/config/nginx/conf.d/grafana_nginx.conf"
    destination = "/tmp/grafana_nginx.conf"
  }

  provisioner "shell" {
    inline = [
      "sudo apt install -y curl gnupg2 ca-certificates lsb-release ubuntu-keyring",
      "curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null",
      "echo \"deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu `lsb_release -cs` nginx\" | sudo tee /etc/apt/sources.list.d/nginx.list",
      "sudo apt update",
      "sudo apt install -y nginx",
      "sudo mv /tmp/grafana_nginx.conf /etc/nginx/conf.d/default.conf"
    ]
  }
}

