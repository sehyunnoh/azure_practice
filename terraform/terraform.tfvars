backend_rg_name        = "pilot-mgmt-rg"
backend_storage_name   = "pilotbackendstorage123"
backend_container_name = "tfstate"

location             = "Canada Central"
service_rg_name      = "pilot-service-rg"
service_storage_name = "pilotappstorage123"

func_plan_name = "pilot-flex-plan"
func_app_name  = "pilot-blob-func"
containers = [
  "inbound",
  "archive",
  "out-united",
  "out-elf",
  "out-economics"
]
