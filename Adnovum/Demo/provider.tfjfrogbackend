terraform {
  required_version = ">= 1.0"

  backend "remote" {
    hostname     = "psblr.jfrog.io"
    organization = "adnovum-terraformbackend"
    workspaces {
      name = "jfrog-curation"
    }
  }

  required_providers {
    xray = {
      source  = "jfrog/xray"
      version = "~> 3.1"
    }
  }
}

provider "xray" {
  url          = var.jfrog_url
  access_token = var.jfrog_access_token
}
