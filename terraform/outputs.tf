output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "function_app_name" {
  value = azurerm_function_app_flex_consumption.func.name
}

output "storage_account_name" {
  value = azurerm_storage_account.storage.name
}
