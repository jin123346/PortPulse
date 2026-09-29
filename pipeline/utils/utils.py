

import json
import logging
from datetime import datetime


# =========================================================
# 공통 유틸
# =========================================================

def normalize_datetime(value):
    """
    문자열 ISO datetime을 Python datetime으로 변환한다.
    이미 datetime이면 그대로 반환한다.
    """
    if value is None:
        return None

    if isinstance(value, str):
        return datetime.fromisoformat(value)

    return value

def normalize_datetime_key(value):
    if value is None:
        return None

    if isinstance(value, datetime):
        dt = value
    else:
        dt = datetime.fromisoformat(value)

    return dt.strftime("%Y-%m-%d %H:%M:%S")

def get_arrival_dt(ship_call):
    """
    ship_call의 details 중 '입항' 이벤트의 etryptDt를 반환한다.
    """
    for detail in ship_call.get("details", []):
        if detail.get("etryndNm") == "입항":
            value = detail.get("etryptDt")

            if value:
                return normalize_datetime(value)

    return None


def is_changed(existing_raw_payload, new_raw_payload):
    """
    기존 JSONB와 신규 raw_payload를 비교한다.
    """

    if isinstance(existing_raw_payload, str):
        existing_raw_payload = json.loads(existing_raw_payload)

    if isinstance(new_raw_payload, str):
        new_raw_payload = json.loads(new_raw_payload)

    return existing_raw_payload != new_raw_payload
