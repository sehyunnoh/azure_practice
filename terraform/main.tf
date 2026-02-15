variable "location" {
  default = "Canada Central"
}

variable "resource_group" {
  default = "poc-rg"
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group
  location = var.location
}

resource "azurerm_storage_account" "storage" {
  name                     = "poc123teststorage"
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
  name                = "poc-func-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption Plan
}

# Function App
resource "azurerm_linux_function_app" "func" {
  name                       = "poc-blob-func-123"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  service_plan_id            = azurerm_service_plan.plan.id
  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key

  site_config {
    application_stack {
      python_version = "3.10"
    }
  }
}
