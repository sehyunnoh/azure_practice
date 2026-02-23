import logging
import os
import azure.functions as func
from azure.storage.blob import BlobClient
from azure.identity import DefaultAzureCredential

# -----------------------------
# 환경 변수
# -----------------------------
STORAGE_ACCOUNT_URL = os.getenv("STORAGE_ACCOUNT_URL")  # 예: https://<storage_account>.blob.core.windows.net
STORAGE_ACCOUNT_KEY = os.getenv("STORAGE_ACCOUNT_KEY")  # 로컬 테스트용, Azure 배포시 None

ARCHIVE_CONTAINER = os.getenv("ARCHIVE_CONTAINER", "archive")

OUT_CONTAINERS = {
    "united": os.getenv("OUT_UNIFIED_CONTAINER", "out-united"),
    "elf": os.getenv("OUT_ELF_CONTAINER", "out-elf"),
    "economics": os.getenv("OUT_ECONOMICS_CONTAINER", "out-economics")
}

# -----------------------------
# 인증 방식 결정
# -----------------------------
if STORAGE_ACCOUNT_KEY:
    credential = STORAGE_ACCOUNT_KEY  # 로컬: Account Key 사용
else:
    credential = DefaultAzureCredential()  # Azure: Managed Identity 사용

# -----------------------------
# Function App
# -----------------------------
def main(myblob: func.InputStream):
    logging.info("Blob trigger fired!")

    # full path: inbound/2026-02-16-elf.csv
    full_name = myblob.name

    # 파일 이름만 추출
    file_name = os.path.basename(full_name)
    logging.info(f"File name: {file_name}")

    blob_bytes = myblob.read()

    # -----------------------------
    # Archive 업로드
    # -----------------------------
    archive_client = BlobClient(
        account_url=STORAGE_ACCOUNT_URL,
        container_name=ARCHIVE_CONTAINER,
        blob_name=file_name,
        credential=credential
    )
    archive_client.upload_blob(blob_bytes, overwrite=True)

    # -----------------------------
    # Out containers 업로드
    # -----------------------------
    lower_name = file_name.lower()

    for key, container in OUT_CONTAINERS.items():
        if key in lower_name:
            out_client = BlobClient(
                account_url=STORAGE_ACCOUNT_URL,
                container_name=container,
                blob_name=file_name,
                credential=credential
            )
            out_client.upload_blob(blob_bytes, overwrite=True)
            logging.info(f"Uploaded blob to container: {container}")
            break

    # -----------------------------
    # inbound 파일 삭제
    # -----------------------------
    inbound_client = BlobClient(
        account_url=STORAGE_ACCOUNT_URL,
        container_name="inbound",
        blob_name=file_name,
        credential=credential
    )
    inbound_client.delete_blob()
    logging.info(f"Deleted original blob: {file_name}")