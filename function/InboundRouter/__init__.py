import logging
import os
from azure.storage.blob import BlobClient

# 환경 변수
STORAGE_ACCOUNT_URL = os.getenv("STORAGE_ACCOUNT_URL")
STORAGE_ACCOUNT_KEY = os.getenv("STORAGE_ACCOUNT_KEY")

ARCHIVE_CONTAINER = "archive"

OUT_CONTAINERS = {
    "united": "out-united",
    "elf": "out-elf",
    "economics": "out-economics"
}


def main(myblob: bytes, name: str):
    logging.info(f"Blob trigger fired!")
    logging.info(f"File name: {name}")
    logging.info(f"File size: {len(myblob)} bytes")

    # 1️⃣ Validation (현재는 항상 True)
    validation_passed = True
    logging.info(f"Validation result: {validation_passed}")

    if not validation_passed:
        logging.error("Validation failed")
        return

    # 2️⃣ Archive 저장
    archive_client = BlobClient(
        account_url=STORAGE_ACCOUNT_URL,
        container_name=ARCHIVE_CONTAINER,
        blob_name=name,
        credential=STORAGE_ACCOUNT_KEY
    )

    archive_client.upload_blob(myblob, overwrite=True)
    logging.info(f"Archived to {ARCHIVE_CONTAINER}/{name}")

    # 3️⃣ 파일명에 따라 분기
    lower_name = name.lower()

    for key, container in OUT_CONTAINERS.items():
        if key in lower_name:
            out_client = BlobClient(
                account_url=STORAGE_ACCOUNT_URL,
                container_name=container,
                blob_name=name,
                credential=STORAGE_ACCOUNT_KEY
            )
            out_client.upload_blob(myblob, overwrite=True)
            logging.info(f"Copied to {container}/{name}")
            return

    logging.warning("No matching out-container found.")
