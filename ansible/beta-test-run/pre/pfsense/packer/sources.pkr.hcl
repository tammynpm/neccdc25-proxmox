locals { timestamp = formatdate("YYYY-MM-DD-hh-mm", timestamp()) }

variable "pfsense_username" {
  type        = string
  description = "Username when authenticating to pfsense, default is admin."
  default     = "admin"
}

variable "pfsense_password" {
  type        = string
  description = "Password for the pfsense user."
  sensitive   = true
}

variable "pfsense_version" {
  type        = string
  description = "pfSense version to use"
  default     = "24.03"

  validation {
    condition     = contains(["24.03", "24.11"], var.pfsense_version)
    error_message = "Invalid pfSense version must be 24.03 or 24.11."
  }
}

source "amazon-ebs" "vm" {
  region                      = "us-east-2"
  ami_name                    = "packer-pfsense-${var.pfsense_version}-${local.timestamp}"
  instance_type               = "c5.xlarge"
  subnet_id                   = "subnet-04255ba24872d7d79"
  security_group_id           = "sg-027af0024a1813997"
  associate_public_ip_address = true
  profile                     = "neccdc-2025"

  source_ami_filter {
    most_recent = true
    owners      = ["aws-marketplace"]
    
    filters = {
       name = "pfSense-plus-ec2-${var.pfsense_version}-RELEASE-amd64*"
    }
  }

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_type           = "gp3"
    volume_size           = 32
    delete_on_termination = true
  }

  user_data = "password=${var.pfsense_password}"

  communicator         = "ssh"
  ssh_username         = "${var.pfsense_username}"
  ssh_password         = "${var.pfsense_password}"
  ssh_keypair_name     = "black-team"
  ssh_private_key_file = "../../../../../documentation/black_team/black-team"

  tags = {
    "Name" = "packer-pfsense-${var.pfsense_version}"
    "date" = "${local.timestamp}"
  }
  run_tags = {
    "Name" = "packer-tmp-build-server-pfsense"
  }
}
