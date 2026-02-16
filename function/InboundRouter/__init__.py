import logging
import os
import azure.functions as func
from azure.storage.blob import BlobClient

STORAGE_ACCOUNT_URL = os.getenv("STORAGE_ACCOUNT_URL")
STORAGE_ACCOUNT_KEY = os.getenv("STORAGE_ACCOUNT_KEY")

ARCHIVE_CONTAINER = "archive"

OUT_CONTAINERS = {
    "united": "out-united",
    "elf": "out-elf",
    "economics": "out-economics"
}

def main(myblob: func.InputStream):
    logging.info("Blob trigger fired!")

    # full path: inbound/2026-02-16-elf.csv
    full_name = myblob.name

    # extract only the file name
    file_name = os.path.basename(full_name)
    logging.info(f"File name: {file_name}")

    blob_bytes = myblob.read()

    # Archive upload
    archive_client = BlobClient(
        account_url=STORAGE_ACCOUNT_URL,
        container_name=ARCHIVE_CONTAINER,
        blob_name=file_name,
        credential=STORAGE_ACCOUNT_KEY
    )
    archive_client.upload_blob(blob_bytes, overwrite=True)

    lower_name = file_name.lower()

    for key, container in OUT_CONTAINERS.items():
        if key in lower_name:
            out_client = BlobClient(
                account_url=STORAGE_ACCOUNT_URL,
                container_name=container,
                blob_name=file_name,
                credential=STORAGE_ACCOUNT_KEY
            )
            out_client.upload_blob(blob_bytes, overwrite=True)
            break

    # -----------------------------
    # 🔥 마지막 단계: inbound 파일 삭제
    # -----------------------------
    inbound_client = BlobClient(
        account_url=STORAGE_ACCOUNT_URL,
        container_name="inbound",
        blob_name=file_name,   # inbound/ 경로 제거된 파일명
        credential=STORAGE_ACCOUNT_KEY
    )

    inbound_client.delete_blob()
    logging.info(f"Deleted original blob: {file_name}")