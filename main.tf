terraform {
  required_providers {
    netapp-cloudmanager = {
      source  = "NetApp/netapp-cloudmanager"
      version = "21.1.1"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}

provider "netapp-cloudmanager" {
  # Configuration options
  refresh_token = var.cloudmanager_refresh_token
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  subscription_id = var.azure_sub_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  tenant_id       = var.azure_tenant_id
}

variable "cloudmanager_refresh_token" {
  type      = string
  sensitive = true
}

variable "cloudmanager_location" {
  type    = string
  default = "West Europe"
}

variable "azure_sub_id" {
  type      = string
  sensitive = true
}

variable "cloudmanager_account_id" {
  type      = string
  sensitive = true
}

variable "azure_client_id" {
  type      = string
  sensitive = true
}

variable "azure_client_secret" {
  type      = string
  sensitive = true
}

variable "azure_tenant_id" {
  type      = string
  sensitive = true
}

resource "azurerm_resource_group" "rg_cloudmanager_connector" {
  name     = "rg_cloudmanager_connector"
  location = var.cloudmanager_location
}

resource "azurerm_virtual_network" "cloudmanager_network" {
  name                = "cloudmanager_network"
  location            = azurerm_resource_group.rg_cloudmanager_connector.location
  resource_group_name = azurerm_resource_group.rg_cloudmanager_connector.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "kitc"
  }
}

resource "azurerm_role_definition" "Azure_SetupAsService" {
  name        = "AzureSetupAsService"
  scope       = "/subscriptions/${var.azure_sub_id}"
  description = "This is the role required to setup"

  permissions {
    actions = [
      "Microsoft.Compute/disks/delete",
      "Microsoft.Compute/disks/read",
      "Microsoft.Compute/disks/write",
      "Microsoft.Compute/locations/operations/read",
      "Microsoft.Compute/operations/read",
      "Microsoft.Compute/virtualMachines/instanceView/read",
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachines/write",
      "Microsoft.Compute/virtualMachines/delete",
      "Microsoft.Compute/virtualMachines/extensions/write",
      "Microsoft.Compute/virtualMachines/extensions/read",
      "Microsoft.Compute/availabilitySets/read",
      "Microsoft.Network/locations/operationResults/read",
      "Microsoft.Network/locations/operations/read",
      "Microsoft.Network/networkInterfaces/join/action",
      "Microsoft.Network/networkInterfaces/read",
      "Microsoft.Network/networkInterfaces/write",
      "Microsoft.Network/networkInterfaces/delete",
      "Microsoft.Network/networkSecurityGroups/join/action",
      "Microsoft.Network/networkSecurityGroups/read",
      "Microsoft.Network/networkSecurityGroups/write",
      "Microsoft.Network/virtualNetworks/checkIpAddressAvailability/read",
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/subnets/join/action",
      "Microsoft.Network/virtualNetworks/subnets/read",
      "Microsoft.Network/virtualNetworks/subnets/virtualMachines/read",
      "Microsoft.Network/virtualNetworks/virtualMachines/read",
      "Microsoft.Network/publicIPAddresses/write",
      "Microsoft.Network/publicIPAddresses/read",
      "Microsoft.Network/publicIPAddresses/delete",
      "Microsoft.Network/networkSecurityGroups/securityRules/read",
      "Microsoft.Network/networkSecurityGroups/securityRules/write",
      "Microsoft.Network/networkSecurityGroups/securityRules/delete",
      "Microsoft.Network/publicIPAddresses/join/action",
      "Microsoft.Network/locations/virtualNetworkAvailableEndpointServices/read",
      "Microsoft.Network/networkInterfaces/ipConfigurations/read",
      "Microsoft.Resources/deployments/operations/read",
      "Microsoft.Resources/deployments/read",
      "Microsoft.Resources/deployments/delete",
      "Microsoft.Resources/deployments/cancel/action",
      "Microsoft.Resources/deployments/validate/action",
      "Microsoft.Resources/resources/read",
      "Microsoft.Resources/subscriptions/operationresults/read",
      "Microsoft.Resources/subscriptions/resourceGroups/delete",
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Resources/subscriptions/resourcegroups/resources/read",
      "Microsoft.Resources/subscriptions/resourceGroups/write",
      "Microsoft.Authorization/roleDefinitions/write",
      "Microsoft.Authorization/roleAssignments/write",
      "Microsoft.MarketplaceOrdering/offertypes/publishers/offers/plans/agreements/read",
      "Microsoft.MarketplaceOrdering/offertypes/publishers/offers/plans/agreements/write",
      "Microsoft.Network/networkSecurityGroups/delete",
      "Microsoft.Storage/storageAccounts/delete",
      "Microsoft.Storage/storageAccounts/write",
      "Microsoft.Resources/deployments/write",
      "Microsoft.Resources/deployments/operationStatuses/read",
      "Microsoft.Authorization/roleAssignments/read"
    ]
    not_actions = []
  }
}

resource "azurerm_network_security_group" "sg_cloudmanager" {
  name                = "sg_cloudmanager"
  location            = var.cloudmanager_location
  resource_group_name = azurerm_resource_group.rg_cloudmanager_connector.name

  security_rule {
    name                       = "cloudmanager_connector"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_ranges         = ["22", "80", "443"]
    destination_port_ranges    = ["*"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "cloudmanager_connector"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_ranges         = ["*"]
    destination_port_ranges    = ["*"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_subnet" "cloudmanager_subnet" {
  name                 = "cloudmanager_subnet"
  resource_group_name  = azurerm_resource_group.rg_cloudmanager_connector.name
  virtual_network_name = azurerm_virtual_network.cloudmanager_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "cloudmanager_subsec_association" {
  subnet_id                 = azurerm_subnet.cloudmanager_subnet.id
  network_security_group_id = azurerm_network_security_group.sg_cloudmanager.id
}

resource "netapp-cloudmanager_connector_azure" "cl-occm-azure" {
  provider                    = netapp-cloudmanager
  name                        = "TF-ConnectorAzure"
  location                    = var.cloudmanager_location
  subscription_id             = var.azure_sub_id
  company                     = "kirkinthecloud"
  resource_group              = azurerm_resource_group.rg_cloudmanager_connector.name
  subnet_id                   = azurerm_subnet.cloudmanager_subnet.name
  vnet_id                     = azurerm_virtual_network.cloudmanager_network.name
  network_security_group_name = azurerm_network_security_group.sg_cloudmanager.name
  associate_public_ip_address = true
  account_id                  = var.cloudmanager_account_id
  admin_password              = "P@ssword123456"
  admin_username              = "vmadmin"
}