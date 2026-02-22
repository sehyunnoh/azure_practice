output "backend_rg_name" {
  value = azurerm_resource_group.mgmt.name
}

output "backend_storage_account" {
  value = azurerm_storage_account.backend.name
}

output "backend_container" {
  value = azurerm_storage_container.tfstate.name
}
