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
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"

  depends_on = [
    azurerm_storage_account.storage
  ]
}

# -----------------------------
# 4. App Service Plan (Y1)
# -----------------------------
resource "azurerm_service_plan" "plan" {
  name                = "pilot-func-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "Y1"

  depends_on = [
    azurerm_storage_account.storage
  ]
}

# -----------------------------
# 5. Function App
# -----------------------------
resource "azurerm_linux_function_app" "func" {
  name                       = "pilot-blob-func"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  service_plan_id            = azurerm_service_plan.plan.id
  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key

  depends_on = [
    azurerm_service_plan.plan,
    azurerm_storage_container.containers
  ]

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.10"
    }
  }

  app_settings = {
    STORAGE_ACCOUNT_URL = "https://${azurerm_storage_account.storage.name}.blob.core.windows.net"
  }
}

# -----------------------------
# 6. Role Assignment
# -----------------------------
resource "azurerm_role_assignment" "func_storage_access" {
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.func.identity[0].principal_id

  depends_on = [
    azurerm_linux_function_app.func
  ]
}
