terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.9.0"
    }
  }

  backend "local" {}
}

provider "azurerm" {
  features {}
}

# -----------------------------
# Resource Group
# -----------------------------
resource "azurerm_resource_group" "mgmt" {
  name     = var.backend_rg_name
  location = var.backend_location
}

# -----------------------------
# Storage Account
# -----------------------------
resource "azurerm_storage_account" "backend" {
  name                     = var.backend_storage_name
  resource_group_name      = azurerm_resource_group.mgmt.name
  location                 = azurerm_resource_group.mgmt.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# -----------------------------
# Storage Container
# -----------------------------
resource "azurerm_storage_container" "tfstate" {
  name                  = var.backend_container_name
  storage_account_name  = azurerm_storage_account.backend.name
  container_access_type = "private"
}
