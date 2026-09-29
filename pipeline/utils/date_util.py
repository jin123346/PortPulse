from datetime import datetime, date


def to_api_date(value: str | date | datetime) -> str:
    """
    날짜 값을 MOF API 요청 형식(YYYYMMDD)으로 변환한다.

    지원:
    - "20260902"
    - "2026-09-02"
    - datetime.date
    - datetime.datetime
    """

    if isinstance(value, datetime):
        return value.strftime("%Y%m%d")

    if isinstance(value, date):
        return value.strftime("%Y%m%d")

    if isinstance(value, str):
        value = value.strip()

        # YYYYMMDD
        if len(value) == 8 and value.isdigit():
            return value

        # YYYY-MM-DD
        try:
            return datetime.strptime(
                value,
                "%Y-%m-%d"
            ).strftime("%Y%m%d")
        except ValueError:
            pass

    raise ValueError(
        f"지원하지 않는 날짜 형식입니다: {value!r}"
    )