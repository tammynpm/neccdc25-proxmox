# https://www.packer.io/plugins/builders/amazon/ebs
source "amazon-ebs" "vm" {
  region            = "us-east-2"
  ami_name          = "packer-database-${formatdate("YYYY-MMM-DD-hh-mm", timestamp())}"
  subnet_id         = "subnet-04255ba24872d7d79"
  security_group_id = "sg-027af0024a1813997"

  # https://aws.amazon.com/marketplace/pp/prodview-k66o7o642dfve
  # CentOS-Stream-ec2-9 (x86_64) for HVM Instances
  source_ami                  = "ami-011d59a275b482a49"
  instance_type               = "t3a.xlarge"
  associate_public_ip_address = true

  profile = "neccdc-2025"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_type           = "gp3"
    volume_size           = 24
    delete_on_termination = true
  }

  tags = {
    "Name" = "packer-database"
    "date" = formatdate("YYYY-MM-DD hh:mm", timestamp())
  }
  run_tags = {
    "Name" = "packer-tmp-build-server-database"
  }
}
