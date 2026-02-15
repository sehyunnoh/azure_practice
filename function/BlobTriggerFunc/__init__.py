import logging
from azure.storage.blob import BlobClient, ContainerClient
from datetime import datetime
import os

# 환경 변수에서 Storage URL 가져오기
ARCHIVE_CONTAINER = os.getenv("ARCHIVE_CONTAINER", "archive")
OUT_CONTAINERS = {
    "united": os.getenv("OUT_UNITED_CONTAINER", "out-united"),
    "elf": os.getenv("OUT_ELF_CONTAINER", "out-elf"),
    "economics": os.getenv("OUT_ECONOMICS_CONTAINER", "out-economics")
}

STORAGE_ACCOUNT_URL = os.getenv("STORAGE_ACCOUNT_URL")  # https://<account>.blob.core.windows.net
STORAGE_ACCOUNT_KEY = os.getenv("STORAGE_ACCOUNT_KEY")

def main(myblob: bytes, name: str):
    logging.info(f"Blob trigger fired! Name: {name}, Size: {len(myblob)} bytes")

    # ------------------------
    # 1️⃣ Validation (지금은 True)
    # ------------------------
    validation_passed = True
    logging.info(f"Validation result: {validation_passed}")

    if validation_passed:
        # ------------------------
        # 2️⃣ Archive에 저장
        # ------------------------
        archive_client = BlobClient(
            account_url=STORAGE_ACCOUNT_URL,
            container_name=ARCHIVE_CONTAINER,
            blob_name=name,
            credential=STORAGE_ACCOUNT_KEY
        )
        archive_client.upload_blob(myblob, overwrite=True)
        logging.info(f"Archived to {ARCHIVE_CONTAINER}/{name}")

        # ------------------------
        # 3️⃣ Out-* Container 이동
        # ------------------------
        for key, container in OUT_CONTAINERS.items():
            if key in name.lower():
                out_client = BlobClient(
                    account_url=STORAGE_ACCOUNT_URL,
                    container_name=container,
                    blob_name=name,
                    credential=STORAGE_ACCOUNT_KEY
                )
                out_client.upload_blob(myblob, overwrite=True)
                logging.info(f"Copied to {container}/{name}")
                break
