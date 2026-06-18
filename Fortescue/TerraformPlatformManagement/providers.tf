terraform {
  required_providers {
    artifactory = {
      source  = "jfrog/artifactory"
      version = "~> 12.0"
    }
    platform = {
      source  = "jfrog/platform"
      version = "~> 2.0"
    }
    xray = {
      source  = "jfrog/xray"
      version = "~> 3.1"
    }
  }
}

provider "artifactory" {
  url          = "https://psblr.jfrog.io"
  access_token = var.artifactory_token
}

provider "platform" {
  url          = "https://psblr.jfrog.io"
  access_token = var.artifactory_token
}

provider "xray" {
  url          = "https://psblr.jfrog.io"
  access_token = var.artifactory_token
}

