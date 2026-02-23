import logging
import os
import azure.functions as func
from azure.storage.blob import BlobClient
from azure.identity import DefaultAzureCredential

STORAGE_ACCOUNT_URL = os.getenv("STORAGE_ACCOUNT_URL")  # 예: https://<storage_account>.blob.core.windows.net

ARCHIVE_CONTAINER = "archive"
OUT_CONTAINERS = {
    "united": "out-united",
    "elf": "out-elf",
    "economics": "out-economics"
}

credential = DefaultAzureCredential()

def main(event: func.EventGridEvent):
    logging.info("EventGrid trigger fired!")

    data = event.get_json()
    # Blob URL: data["url"]
    blob_url = data["url"]
    logging.info(f"Blob URL: {blob_url}")

    # Blob 이름 추출
    file_name = os.path.basename(blob_url)
    logging.info(f"File name: {file_name}")

    # BlobClient 생성 (MSI 인증)
    blob_client = BlobClient(blob_url, credential=credential)
    blob_bytes = blob_client.download_blob().readall()

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
            break

    # -----------------------------
    # 원본 Blob 삭제
    # -----------------------------
    inbound_client = BlobClient(
        account_url=STORAGE_ACCOUNT_URL,
        container_name="inbound",
        blob_name=file_name,
        credential=credential
    )
    inbound_client.delete_blob()
    logging.info(f"Deleted original blob: {file_name}")