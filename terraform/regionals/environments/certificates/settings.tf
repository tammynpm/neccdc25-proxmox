terraform {
  required_version = "~> 1.9.0"

  backend "s3" {
    bucket = "neccdc25-bucket-terraform"
    key    = "regionals/certificates/terraform.tfstate"
    region = "us-east-2"

    profile = "neccdc-2025"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.73.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "2.27.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.6"
    }
  }
}

provider "aws" {
  region = var.region

  profile = "neccdc-2025"

  default_tags {
    tags = {
      terraform = "true"
      path      = "terraform/regionals/environments/certificates"
    }
  }
}

provider "acme" {
  # Staging endpoint 
  # server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"

  # Production endpoint
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}
