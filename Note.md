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

## How to use Function in the local
- Azure Functions Core Tools 설치
```
sudo apt update
sudo apt install nodejs npm -y
sudo npm install -g azure-functions-core-tools@4 --unsafe-perm true
```

- 로컬에서 Azure Storage 와 연결하기
   - local.settings.json 생성
```
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "<Azure Storage Connection String>",
    "STORAGE_ACCOUNT_URL": "https://<account>.blob.core.windows.net",
    "STORAGE_ACCOUNT_KEY": "<Access Key>",
    "FUNCTIONS_WORKER_RUNTIME": "python"
  }
}
```

- 패키지 설치
```
pip install -r requirements.txt
```

- Blob Trigger 확장 설치 확인
```
func extensions install
```

- 로컬 Function 실행
```
~/function/func start
```