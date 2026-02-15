import logging
import os
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobClient

credential = DefaultAzureCredential()

STORAGE_ACCOUNT_URL = os.getenv("STORAGE_ACCOUNT_URL")

ARCHIVE_CONTAINER = "archive"

OUT_CONTAINERS = {
    "united": "out-united",
    "elf": "out-elf",
    "economics": "out-economics"
}


def main(myblob: bytes, name: str):
    logging.info(f"Blob trigger fired!")
    logging.info(f"File name: {name}")

    validation_passed = True

    if not validation_passed:
        logging.error("Validation failed")
        return

    # Archive
    archive_client = BlobClient(
        account_url=STORAGE_ACCOUNT_URL,
        container_name=ARCHIVE_CONTAINER,
        blob_name=name,
        credential=credential
    )
    archive_client.upload_blob(myblob, overwrite=True)

    lower_name = name.lower()

    for key, container in OUT_CONTAINERS.items():
        if key in lower_name:
            out_client = BlobClient(
                account_url=STORAGE_ACCOUNT_URL,
                container_name=container,
                blob_name=name,
                credential=credential
            )
            out_client.upload_blob(myblob, overwrite=True)
            return
