output "function_app_name" {
  value = azurerm_linux_function_app.func.name
}

output "storage_account_name" {
  value = azurerm_storage_account.storage.name
}

output "resource_group" {
  value = azurerm_resource_group.rg.name
}
