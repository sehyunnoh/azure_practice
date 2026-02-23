import logging
import os
import azure.functions as func
from azure.storage.blob import BlobClient
from azure.identity import DefaultAzureCredential

# 전역에서 선언하면 함수 호출마다 재인증하지 않아 성능에 좋습니다.
credential = DefaultAzureCredential()

def main(event: func.EventGridEvent):
    # 중요: STORAGE_ACCOUNT_URL이 없으면 에러가 나므로 체크 로직 추가
    storage_url = os.getenv("STORAGE_ACCOUNT_URL")
    if not storage_url:
        logging.error("STORAGE_ACCOUNT_URL environment variable is not set.")
        return

    logging.info("EventGrid trigger fired!")

    data = event.get_json()
    # Event Grid에서 오는 데이터 중 blob url을 가져옵니다.
    blob_url = data.get("url")
    if not blob_url:
        logging.error("No URL found in event data.")
        return

    logging.info(f"Processing Blob: {blob_url}")

    file_name = os.path.basename(blob_url)
    
    # 1. 원본 Blob 다운로드
    blob_client = BlobClient(blob_url, credential=credential)
    blob_bytes = blob_client.download_blob().readall()

    # 2. Archive 업로드
    archive_client = BlobClient(
        account_url=storage_url,
        container_name="archive",
        blob_name=file_name,
        credential=credential
    )
    archive_client.upload_blob(blob_bytes, overwrite=True)
    logging.info(f"Archived: {file_name}")

    # 3. 조건부 배분 (United, Elf, Economics)
    out_containers = {
        "united": "out-united",
        "elf": "out-elf",
        "economics": "out-economics"
    }
    
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
            logging.info(f"Distributed to {container}: {file_name}")
            break

    # 4. 원본 삭제 (inbound 컨테이너)
    # Event Grid 데이터에서 추출한 URL을 사용하여 바로 삭제 가능
    blob_client.delete_blob()
    logging.info(f"Deleted original blob: {file_name}")