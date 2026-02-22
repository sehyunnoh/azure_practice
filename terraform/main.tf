terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.9.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = var.backend_rg_name
    storage_account_name = var.backend_storage_name
    container_name       = var.backend_container_name
    key                  = var.backend_state_key
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
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
  containers = var.containers
}

resource "azurerm_storage_container" "containers" {
  for_each              = toset(local.containers)
  name                  = each.value
  storage_account_id    = azurerm_storage_account.storage.id
  container_access_type = "private"
}

# -----------------------------
# 4. Flex Consumption Plan
# -----------------------------
resource "azurerm_service_plan" "func_plan" {
  name                = var.func_plan_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  os_type  = "Linux"
  sku_name = "FC1"
}

# -----------------------------
# 5. Linux Function App
# -----------------------------
resource "azurerm_linux_function_app" "func" {
  name                = var.func_app_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.func_plan.id

  storage_account_name = azurerm_storage_account.storage.name

  identity {
    type = "SystemAssigned"
  }

  # Flex Consumption requires function_app_config on create
  function_app_config {
    deployment {
      storage {
        type         = "blobContainer"
        container_id = azurerm_storage_container.containers["deploy"].resource_manager_id
      }
    }
  }


  site_config {
    application_stack {
      python_version = "3.10"
    }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
  }
}

# -----------------------------
# 6. Role Assignment
# -----------------------------
resource "azurerm_role_assignment" "func_storage_blob_contrib" {
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.func.identity[0].principal_id
}
