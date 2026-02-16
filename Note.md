## How to get Azure_crendentials
  - GitHub Actions에서 Azure에 로그인하기 위한 Serivce Principal JSON

```
az login

// subscription ID 가져오기
az account show --query id -o tsv

// Service Principal 생성
// GitHub Actions에서 사용할 수 있도록 JSON 형태로 출력됨
az ad sp create-for-rbac \
  --name github-sp-terraform \
  --role contributor \
  --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID> \
  --sdk-auth

// 출력된 JSON을 GitHub Actions의 시크릿에 저장

```