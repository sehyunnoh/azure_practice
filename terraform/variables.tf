variable "location" {
  type    = string
  default = "Canada Central"
}

variable "service_rg_name" {
  type    = string
  default = "pilot-service-rg"
}

variable "service_storage_name" {
  type    = string
  default = "pilotappstorage123"
}

variable "containers" {
  type = list(string)
  default = [
    "inbound",
    "archive",
    "out-united",
    "out-elf",
    "out-economics"
  ]
}

variable "func_plan_name" {
  type    = string
  default = "pilot-flex-plan"
}

variable "func_app_name" {
  type    = string
  default = "pilot-blob-func"
}
