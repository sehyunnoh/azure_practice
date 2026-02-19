terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "pilot-mgmt-rg"
    storage_account_name = "pilotbackendstorage123"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# -----------------------------
# Variables
# -----------------------------
variable "location" {
  default = "Canada Central"
}

variable "service_rg_name" {
  default = "pilot-service-rg"
}

variable "service_storage_name" {
  default = "pilotappstorage123"
}

# -----------------------------
# 1. Resource Group
# -----------------------------
resource "azurerm_resource_group" "rg" {
  name     = var.service_rg_name
  location = var.location
}

# -----------------------------
# 2. Storage Account
# -----------------------------
resource "azurerm_storage_account" "storage" {
  name                     = var.service_storage_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  timeouts {
    create = "10m"
  }
}

# -----------------------------
# 3. Blob Containers
# -----------------------------
locals {
  containers = ["inbound", "archive", "out-united", "out-elf", "out-economics"]
}

resource "azurerm_storage_container" "containers" {
  for_each              = toset(local.containers)
  name                  = each.value
  storage_account_id    = azurerm_storage_account.storage.id
  container_access_type = "private"
}

# -----------------------------
# 4. Function App (Flex Consumption)
# -----------------------------
resource "azurerm_linux_function_app_flex" "func" {
  name                = "pilot-blob-func"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku_name = "FC1"

  # Flex Consumption requires a storage account reference
  storage_account_id = azurerm_storage_account.storage.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.10"
    }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
    STORAGE_ACCOUNT_URL      = "https://${azurerm_storage_account.storage.name}.blob.core.windows.net"
  }
}

# -----------------------------
# 5. Role Assignment (Function → Storage)
# -----------------------------
resource "azurerm_role_assignment" "func_storage_blob_contrib" {
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app_flex.func.identity.principal_id
}
