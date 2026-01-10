terraform {
  required_version = "~> 1.9.0"

  backend "s3" {
    bucket = "neccdc25-bucket-terraform"
    key    = "qualifiers/ecr/terraform.tfstate"
    region = "us-east-2"

    profile = "neccdc-2025"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.73.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  profile = "neccdc-2025"

  default_tags {
    tags = {
      terraform = "true"
      path      = "terraform/qualifiers/environments/ecr"
    }
  }
}
