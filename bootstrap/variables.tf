variable "backend_rg_name" {
  type        = string
  description = "Resource group for Terraform backend"
}

variable "backend_location" {
  type        = string
  description = "Azure region for backend resources"
  default     = "Canada Central"
}

variable "backend_storage_name" {
  type        = string
  description = "Storage account name for Terraform backend"
}

variable "backend_container_name" {
  type        = string
  description = "Blob container name for Terraform state"
  default     = "tfstate"
}
