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
# 5. Linux Function App (Flex Consumption)
# -----------------------------
resource "azurerm_function_app_flex_consumption" "func" {
  name                = var.func_app_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.func_plan.id

  # Managed Identity 필수
  identity {
    type = "SystemAssigned"
  }

  # Flex 필수 설정
  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.storage.primary_blob_endpoint}${azurerm_storage_container.containers["deploy"].name}"
  storage_authentication_type = "SystemAssignedIdentity"

  runtime_name    = "python"
  runtime_version = "3.10"

  maximum_instance_count = 50
  instance_memory_in_mb  = 2048

  site_config {}
}

# -----------------------------
# 6. Role Assignment (Function MI → Blob)
# -----------------------------
resource "azurerm_role_assignment" "func_storage_blob_contrib" {
  for_each             = toset(["inbound", "archive", "out-united", "out-elf", "out-economics"])
  scope                = azurerm_storage_container.containers[each.key].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.func.identity[0].principal_id
}

# -----------------------------
# 7. Event Grid Subscription (Blob → Function)
# -----------------------------
resource "azurerm_eventgrid_event_subscription" "inbound_blob_subscription" {
  name  = "inbound-blob-subscription"
  scope = azurerm_storage_account.storage.id

  included_event_types = [
    "Microsoft.Storage.BlobCreated"
  ]

  azure_function_endpoint {
    function_id = azurerm_function_app_flex_consumption.func.id
  }

  retry_policy {
    max_delivery_attempts = 5
    event_time_to_live    = 1440
  }

  # subject filtering for blob container path
  subject_filter {
    subject_begins_with = "/blobServices/default/containers/inbound/"
  }

  depends_on = [
    azurerm_role_assignment.func_storage_blob_contrib
  ]
}
