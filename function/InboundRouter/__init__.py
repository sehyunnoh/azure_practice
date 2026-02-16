import logging
import os
from azure.storage.blob import BlobClient

STORAGE_ACCOUNT_URL = os.getenv("STORAGE_ACCOUNT_URL")
STORAGE_ACCOUNT_KEY = os.getenv("STORAGE_ACCOUNT_KEY")

ARCHIVE_CONTAINER = "archive"

OUT_CONTAINERS = {
    "united": "out-united",
    "elf": "out-elf",
    "economics": "out-economics"
}

def main(myblob: bytes, name: str):
    logging.info("Blob trigger fired!")
    logging.info(f"File name: {name}")
    
    

    # Archive upload
    archive_client = BlobClient(
        account_url=STORAGE_ACCOUNT_URL,
        container_name=ARCHIVE_CONTAINER,
        blob_name=name,
        credential=STORAGE_ACCOUNT_KEY
    )
    archive_client.upload_blob(myblob, overwrite=True)

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
            return