"""_summary_
해양수산부 API 를 사용하여 선박 관제 데이터 를 수집하는 모듈
"""
import time
import requests
import xml.etree.ElementTree as ET
import logging
from config.setting import SERVICE_KEY,MOF_SHIP_CALL_CONTROL_URL



BASE_URL = MOF_SHIP_CALL_CONTROL_URL
logger = logging.getLogger(__name__)


url = f"{BASE_URL}?serviceKey={SERVICE_KEY}"

# 1. 기존 pipeline 실행에 붙어서 관제정보 수집
def fetch_ship_control_call(
    port_code : str | None= None,
    start_date : str | None= None,
    end_date : str | None= None,
    page_no : int= 1,
    num_of_rows: int = 50
):
    logger.info("관제 정보 api 요청 시작 ")
    max_retries = 3
    # 1. run_id가 없는 경우
    if port_code is None or start_date is None or end_date is None:
            raise ValueError(
                "port_code , start_date , end_date 는 모두 필수 입니다."
            )
            
    # 2. 관제정보만 독립적으로 수집
    params = {
            "prtAgCd": port_code,
            "sde": start_date,
            "ede": end_date,
            "pageNo": page_no,
            "numOfRows": num_of_rows
        }
    
    
    for attempt in range(1, max_retries+1):
        try: 
            logger.info("API 요청 시도 - port_code=%s, page_no=%s, attempt=%s/%s",port_code,page_no,attempt, max_retries)
            response = requests.get(
                            url=url,
                            params=params,
                            timeout=(10, 30)
                        )
            
            response.raise_for_status()
            
            return response
        except requests.RequestException as e:
            logger.warning("API 요청실패 - port_code= %s, page_no=%s, attempt=%s/%s, error=%s",
                            port_code,page_no,attempt,max_retries)
            
            if attempt == max_retries:
                raise


    
        