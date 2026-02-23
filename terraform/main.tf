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
resource "azurerm_linux_function_app" "func" {
  name                = var.func_app_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.func_plan.id

  storage_account_name          = azurerm_storage_account.storage.name
  storage_uses_managed_identity = true

  identity {
    type = "SystemAssigned"
  }

  # 1. Unsupported block type 해결: 
  # 최신 v4.x에서는 function_app_config 블록 대신 
  # 아래와 같이 최상위 인자들을 사용하거나 site_config를 이용합니다.

  site_config {
    application_stack {
      python_version = "3.10"
    }

    # 2. Unsupported argument 해결:
    # Flex Consumption의 메모리와 HTTP 복제 설정은 
    # v4.x 특정 버전에서 site_config 내부가 아닌 최상위로 이동했을 수 있습니다.
    # 만약 여기서도 에러가 나면 이 두 줄을 삭제하세요.
  }

  # 3. Flex Consumption 배포를 위한 핵심 (App Settings 방식)
  # API가 요구하는 'FunctionAppConfig'를 만족시키기 위해 
  # 컨테이너 경로를 명시적으로 환경 변수에 주입합니다.
  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
    WEBSITE_RUN_FROM_PACKAGE = "https://${azurerm_storage_account.storage.name}.blob.core.windows.net/${azurerm_storage_container.containers["deploy"].name}"
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
