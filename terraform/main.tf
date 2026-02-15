terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "pilot-rg"
    storage_account_name = "pilotstorage123"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

variable "location" {
  default = "Canada Central"
}

variable "resource_group" {
  default = "pilot-rg"
}

variable "storage_account_name" {
  default = "pilotstorage123"
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group
  location = var.location
}

# Storage Account
resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Blob Containers
locals {
  containers = ["inbound", "archive", "out-united", "out-elf", "out-economics"]
}

resource "azurerm_storage_container" "containers" {
  for_each              = toset(local.containers)
  name                  = each.value
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

# Function App Service Plan
resource "azurerm_service_plan" "plan" {
  name                = "pilot-func-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption Plan
}

# Function App (Managed Identity)
resource "azurerm_linux_function_app" "func" {
  name                       = "pilot-blob-func"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  service_plan_id            = azurerm_service_plan.plan.id
  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.10"
    }
  }

  app_settings = {
    # Storage URL는 Managed Identity 사용 시 읽는 코드에서 reference
    STORAGE_ACCOUNT_URL = "https://${azurerm_storage_account.storage.name}.blob.core.windows.net"
  }
}

# Role Assignment: Function -> Storage
resource "azurerm_role_assignment" "func_storage_access" {
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.func.identity[0].principal_id
}
