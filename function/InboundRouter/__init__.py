import logging
import os
import azure.functions as func
from azure.storage.blob import BlobClient
from azure.identity import DefaultAzureCredential

credential = DefaultAzureCredential()

def main(event: func.EventGridEvent):
    storage_url = os.getenv("STORAGE_ACCOUNT_URL")
    if not storage_url:
        logging.error("STORAGE_ACCOUNT_URL environment variable is not set.")
        return

    data = event.get_json()
    blob_url = data.get("url")
    if not blob_url:
        logging.error("No URL found in event data.")
        return

    logging.info(f"Processing Blob: {blob_url}")
    file_name = os.path.basename(blob_url)
    
    # --- 핵심 수정 부분: from_blob_url 사용 ---
    try:
        blob_client = BlobClient.from_blob_url(blob_url, credential=credential)
        blob_bytes = blob_client.download_blob().readall()
    except Exception as e:
        logging.error(f"Failed to download blob: {str(e)}")
        return

    # 2. Archive 업로드
    archive_client = BlobClient(
        account_url=storage_url,
        container_name="archive",
        blob_name=file_name,
        credential=credential
    )
    archive_client.upload_blob(blob_bytes, overwrite=True)

    # 3. 배분 로직
    out_containers = {"united": "out-united", "elf": "out-elf", "economics": "out-economics"}
    lower_name = file_name.lower()
    for key, container in out_containers.items():
        if key in lower_name:
            out_client = BlobClient(
                account_url=storage_url,
                container_name=container,
                blob_name=file_name,
                credential=credential
            )
            out_client.upload_blob(blob_bytes, overwrite=True)
            break

    # 4. 원본 삭제
    blob_client.delete_blob()
    logging.info(f"Successfully processed and deleted: {file_name}")