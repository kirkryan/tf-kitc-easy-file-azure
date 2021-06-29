terraform {
  required_providers {
    netapp-cloudmanager = {
      source = "NetApp/netapp-cloudmanager"
      version = "21.1.1"
    }
  }
}

provider "netapp-cloudmanager" {
  # Configuration options
  refresh_token = var.cloudmanager_refresh_token
}