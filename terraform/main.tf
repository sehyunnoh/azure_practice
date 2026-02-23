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
# 5. Linux Function App (수정본)
# -----------------------------
# -----------------------------
# 5. Linux Function App (수정 완료)
# -----------------------------
resource "azurerm_function_app_flex_consumption" "func" {
  name                = var.func_app_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.func_plan.id

  identity {
    type = "SystemAssigned"
  }

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.storage.primary_blob_endpoint}${azurerm_storage_container.containers["deploy"].name}"
  storage_authentication_type = "SystemAssignedIdentity"

  runtime_name    = "python"
  runtime_version = "3.10"

  # Flex Consumption의 스케일 제한은 여기서 설정합니다 (이미 설정됨)
  maximum_instance_count = 50
  instance_memory_in_mb  = 2048

  # 에러가 났던 site_config 블록 수정
  site_config {
    # app_scale_limit은 여기서 제거합니다.
    # 필요한 경우 여기에 cors나 다른 설정을 넣습니다.
  }

  app_settings = {
    "PYTHON_ENABLE_WORKER_EXTENSIONS" = "1"
  }
}

# -----------------------------
# 6. 권한 추가 (매우 중요!)
# -----------------------------

# 1) 함수 앱이 자기 자신을 Event Grid 엔드포인트로 등록할 수 있는 권한
resource "azurerm_role_assignment" "func_eventgrid_contributor" {
  scope                = azurerm_function_app_flex_consumption.func.id
  role_definition_name = "EventGrid EventSubscription Contributor"
  principal_id         = azurerm_function_app_flex_consumption.func.identity[0].principal_id
}

# 2) 스토리지에서 데이터를 읽어오기 위한 권한 (이미 작성하신 코드 유지)
resource "azurerm_role_assignment" "func_storage_blob_contrib" {
  for_each             = toset(["inbound", "archive"])
  scope                = azurerm_storage_container.containers[each.key].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.func.identity[0].principal_id
}
