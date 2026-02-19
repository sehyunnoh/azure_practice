terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
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
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
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
  containers = [
    "inbound",
    "archive",
    "out-united",
    "out-elf",
    "out-economics"
  ]
}

resource "azurerm_storage_container" "containers" {
  for_each              = toset(local.containers)
  name                  = each.value
  storage_account_id    = azurerm_storage_account.storage.id
  container_access_type = "private"
}

# -----------------------------
# 4. Flex Consumption Plan (FC1)
# -----------------------------
resource "azurerm_service_plan" "func_plan" {
  name                = "pilot-flex-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  os_type  = "Linux"
  sku_name = "FC1" # 🔥 Flex Consumption
}

# -----------------------------
# 5. Linux Function App (Python + MSI)
# -----------------------------
resource "azurerm_linux_function_app" "func" {
  name                = "pilot-blob-func"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  service_plan_id = azurerm_service_plan.func_plan.id

  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.10" # Python 3.10 지정
    }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
    WEBSITE_RUN_FROM_PACKAGE = "1"
  }

  depends_on = [
    azurerm_service_plan.func_plan
  ]
}


# -----------------------------
# 6. Role Assignment (Function → Storage)
# -----------------------------
locals {
  func_principal_id = try(
    azurerm_linux_function_app.func.identity[0].principal_id,
    null
  )
}

resource "azurerm_role_assignment" "func_storage_blob_contrib" {
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.func.identity[0].principal_id

  depends_on = [azurerm_linux_function_app.func]
}
