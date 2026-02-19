import logging
import os
import azure.functions as func
from azure.storage.blob import BlobClient
from azure.identity import DefaultAzureCredential

# -----------------------------
# 환경 변수
# -----------------------------
STORAGE_ACCOUNT_URL = os.getenv("STORAGE_ACCOUNT_URL")  # 예: https://<storage_account>.blob.core.windows.net

ARCHIVE_CONTAINER = "archive"

OUT_CONTAINERS = {
    "united": "out-united",
    "elf": "out-elf",
    "economics": "out-economics"
}

# MSI 기반 인증
credential = DefaultAzureCredential()

def main(myblob: func.InputStream):
    logging.info("Blob trigger fired!")

    # full path: inbound/2026-02-16-elf.csv
    full_name = myblob.name

    # extract only the file name
    file_name = os.path.basename(full_name)
    logging.info(f"File name: {file_name}")

    blob_bytes = myblob.read()

    # -----------------------------
    # Archive upload
    # -----------------------------
    archive_client = BlobClient(
        account_url=STORAGE_ACCOUNT_URL,
        container_name=ARCHIVE_CONTAINER,
        blob_name=file_name,
        credential=credential
    )
    archive_client.upload_blob(blob_bytes, overwrite=True)

    # -----------------------------
    # Out containers upload
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
            break

    # -----------------------------
    # 마지막 단계: inbound 파일 삭제
    # -----------------------------
    inbound_client = BlobClient(
        account_url=STORAGE_ACCOUNT_URL,
        container_name="inbound",
        blob_name=file_name,
        credential=credential
    )
    inbound_client.delete_blob()
    logging.info(f"Deleted original blob: {file_name}")
