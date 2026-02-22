backend_rg_name        = "dev-mgmt-rg"
backend_storage_name   = "devbackendstorage123"
backend_container_name = "tfstate"

location             = "Canada Central"
service_rg_name      = "dev-service-rg"
service_storage_name = "devappstorage123"

func_plan_name = "dev-flex-plan"
func_app_name  = "dev-blob-func"
containers = [
  "inbound",
  "archive",
  "out-united",
  "out-elf",
  "out-economics"
]
