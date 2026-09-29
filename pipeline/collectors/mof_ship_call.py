"""_summary_
해양수산부 API 를 사용하여 선박운항정보 데이터 를 수집하는 모듈
"""
import time
import requests
import xml.etree.ElementTree as ET
import logging
from config.setting import SERVICE_KEY, MOF_SHIP_CALL_URL
from db.postgres import get_target_ports
from parser.parser import parse_mof_items_xml

BASE_URL = MOF_SHIP_CALL_URL


logger = logging.getLogger(__name__)
#xml 응답 가져오기 
def fetch_ship_calls(
    port_code: str,
    start_date: str ,
    end_date: str ,
    date_type: str = "I",
    call_sign: str | None = None,
    page_no: int = 1,
    num_of_rows: int = 10
):
    max_retries = 3
    logger.info("fetch_ship_calls 호출: port_code=%s, start_date=%s, end_date=%s, date_type=%s, call_sign=%s, page_no=%s, num_of_rows=%s", port_code, start_date, end_date, date_type, call_sign, page_no, num_of_rows)
    url = f"{BASE_URL}?serviceKey={SERVICE_KEY}"

    params = {
        "prtAgCd": port_code,
        "sde": start_date,
        "ede": end_date,
        "deGb": date_type,
        "pageNo": page_no,
        "numOfRows": num_of_rows
    }

    if call_sign:
        params["clsgn"] = call_sign

    for attempt in range(1, max_retries + 1):
        try:
            logger.info(
                "API 요청 시도 - port_code=%s, page_no=%s, attempt=%s/%s",
                port_code,
                page_no,
                attempt,
                max_retries
            )

            response = requests.get(
                url=url,
                params=params,
                timeout=(10, 30)
            )

            response.raise_for_status()


            logger.debug("HTTP STATUS: %s", response.status_code)
            logger.debug("XML 응답 데이터: %s...", response.text[:500])  # Log the first 500 characters of the XML response for debugging
            logger.debug("parse_ship_call_xml 호출")
            return parse_mof_items_xml(response.text)

        except (
            requests.exceptions.ConnectTimeout,
            requests.exceptions.ReadTimeout
        ) as e:

            logger.warning(
                "API Timeout - port_code=%s, page_no=%s, "
                "attempt=%s/%s, error=%s",
                port_code,
                page_no,
                attempt,
                max_retries,
                e
            )

            if attempt == max_retries:
                logger.error(
                    "API Timeout 최종 실패 - port_code=%s, page_no=%s",
                    port_code,
                    page_no
                )
                raise

            wait_seconds = attempt * 2

            logger.info(
                "%s초 후 재시도 - port_code=%s, page_no=%s",
                wait_seconds,
                port_code,
                page_no
            )

            time.sleep(wait_seconds)

        except requests.exceptions.RequestException:
            logger.exception(
                "API 요청 실패 - port_code=%s, page_no=%s",
                port_code,
                page_no
            )
            raise

# # item dick로 변환
# def parse_ship_call_xml(xml_text: str):
#     logger.debug("parse_ship_call_xml 응답 데이터: %s...", xml_text[:500])  # Log the first 500 characters of the XML response for debugging
#     root = ET.fromstring(xml_text)
#     ship_calls = []

#     for item in root.findall(".//item"):
#         ship_call ={}
#         details = []

#         for child in item:
#             if child.tag == "details":
#                 for detail in child.findall("detail"):
#                     detail_data = {}

#                     for detail_child in detail:
#                         detail_data[detail_child.tag] = detail_child.text

#                     details.append(detail_data)
#             else:
#                 ship_call[child.tag] = child.text

#         ship_call["details"] = details
#         ship_calls.append(ship_call)

#     total_count_text = root.findtext(".//totalCount")
#     total_count = int(total_count_text) if total_count_text else 0
#     logger.info("totalCount: %s, type: %s", total_count, type(total_count))

#     return ship_calls, total_count
