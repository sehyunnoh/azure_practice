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
  features {}
}

variable "resource_group_name" {}
variable "storage_account_name" {}
variable "function_app_name" {}
variable "function_key" {}

data "azurerm_storage_account" "storage" {
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
}

data "azurerm_function_app" "func" {
  name                = var.function_app_name
  resource_group_name = var.resource_group_name
}

resource "azurerm_eventgrid_event_subscription" "inbound_blob_subscription" {
  name  = "inbound-blob-subscription"
  scope = data.azurerm_storage_account.storage.id

  webhook_endpoint {
    url = "https://${data.azurerm_function_app.func.default_hostname}/runtime/webhooks/EventGrid?functionName=InboundRouter&code=${var.function_key}"
  }

  event_delivery_schema = "EventGridSchema"
  included_event_types  = ["Microsoft.Storage.BlobCreated"]
}
