👉 **Azure API는 `functionAppConfig`를 요구하는데, azurerm provider가 아직 완전히 지원을 안 해서 생기는 구조적 충돌**이야.

지금 상황을 정확히 정리해보면:

---

## 🔥 문제의 본질

### 1️⃣ Azure 쪽 요구사항 (Flex Consumption)

Microsoft Azure 의 **Flex Consumption (FC1)** 플랜은
기존 Consumption과 다르게:

> `properties.functionAppConfig` 가 반드시 필요

즉, Azure ARM API 레벨에서는 이 JSON이 필수야.

---

### 2️⃣ Terraform azurerm provider 현실

HashiCorp 의
`azurerm >= 4.x` provider에서는:

* `function_app_config` 블록이 **아직 정식 지원 안 됨**
* 넣으면 👉 `Unsupported block type`
* 안 넣으면 👉 Azure API가 거부

그래서 지금 네가 겪는:

> “필수라면서 넣으면 안된다고 함”

이 모순이 발생하는 거야.

---

# ✅ 결론

### ❗ azurerm provider 단독으로는 아직 완전 지원 안 됨

Flex Consumption은 **신규 기능**이라
Terraform provider가 API 업데이트를 완전히 따라가지 못한 상태야.

---

# 💡 해결 방법 3가지

---

## 🥇 해결책 1 (추천) — azapi provider 같이 쓰기

Flex Consumption은
`azurerm_linux_function_app` 대신

👉 `azapi_resource` 로 직접 ARM API 호출해서 만들어야 해.

이게 현재 가장 안정적인 방법이야.

예시 구조:

```hcl
provider "azapi" {}

resource "azapi_resource" "flex_function" {
  type      = "Microsoft.Web/sites@2023-12-01"
  name      = var.func_app_name
  location  = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id

  body = jsonencode({
    kind = "functionapp,linux"
    properties = {
      serverFarmId = azurerm_service_plan.func_plan.id

      functionAppConfig = {
        runtime = {
          name    = "python"
          version = "3.10"
        }
      }

      siteConfig = {
        appSettings = [
          {
            name  = "FUNCTIONS_WORKER_RUNTIME"
            value = "python"
          }
        ]
      }
    }
  })
}
```

👉 이 방식은 Azure가 요구하는 JSON을 그대로 보내기 때문에 에러가 안 남.

---

## 🥈 해결책 2 — Flex 대신 Consumption (Y1) 사용

```hcl
sku_name = "Y1"
```

이렇게 하면 기존 방식으로 문제 없이 작동함.

Flex 꼭 필요하지 않다면 이게 제일 쉬움.

---

## 🥉 해결책 3 — azurerm 최신 베타 기다리기

Provider가 완전히 업데이트될 때까지 기다리는 방법.

하지만 언제 될지 모름.

---

# 🚨 네 코드에서 또 하나 문제

이 부분:

```hcl
storage_account_name          = azurerm_storage_account.storage.name
storage_uses_managed_identity = true
```

Flex에서는:

* Storage connection string 방식이 아니라
* functionAppConfig 안에 storage 정의 필요

그래서 이 부분도 사실 맞지 않는 구조야.

---

# 📌 현실적인 추천 (Eric 상황 기준)

네가:

* GitHub Action으로 Terraform 돌리고 있고
* Azure 처음이고
* Blob trigger + validation 용도라면

👉 지금은 Y1 Consumption 쓰는 게 맞아.

Flex는 아직 Terraform에서 안정적이지 않음.

---

# 🎯 요약

| 항목               | 상태                   |
| ---------------- | -------------------- |
| Azure API        | functionAppConfig 필수 |
| azurerm provider | 아직 완전 지원 안 됨         |
| 네 코드             | 틀린 게 아니라 구조적으로 충돌    |
| 해결책              | azapi 사용 or Y1으로 다운  |

---

원하면 내가

* ✅ azapi 포함한 완성 Terraform 예제
* ✅ Y1 기반으로 안정적인 전체 코드
* ✅ GitHub Action 포함된 배포 파이프라인

중에 어떤 방향으로 갈지 정해줘.

Flex 꼭 써야 하는 이유가 있어?




- [function_app_flex_consumption](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/function_app_flex_consumption)