terraform {
  required_version = "1.12.8"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.109.0"
    }
  }
}

# The provider reads the API token from DIGITALOCEAN_ACCESS_TOKEN.
provider "digitalocean" {}
