import logging
from datetime import date
from decimal import Decimal

from config.setting import SQL_DIR
from db.postgres import get_connection

logger= logging.getLogger(__name__)

MIN_MATCH_PCT=90.0

MAX_MISSING_DAYS=2
MONITORING_SQL="monitoring_summary.sql"

def _to_json_value(v):
    if isinstance(v, Decimal):
        return float(v)
    if isinstance(v,date):
        return v.isoformat()
    return v

def get_monitoring_summary() -> dict:
    sql=(SQL_DIR/MONITORING_SQL).read_text(encoding="utf-8")
    conn= get_connection()
    try:
        with conn.cursor() as cur:
            cur.excute(sql)
            row=cur.fetchone()
            colums = [d[0] for d in cur.description]

        conn.rollback()
    finally:
        conn.close()

    summary = {col: _to_json_value(val) for col,val in zip(colums,row)}
    summary["warnings"]= _check_warnings(summary)

    for w in summary["warnings"]:
        logger.warning("모니터링 경고:%s",w)

    logger.info("모니터링: 신고 %s건, 매칭률 %s%%, 미매칭 %s건, mart %s~%s",
                summary["ship_calls"], summary["match_pct"], summary["unmatched_expected"],
                summary["first_date"], summary["last_date"])
    return summary

def _check_warnings(s: dict) -> list[str]:
    warnings=[]
    if s["match_pct"] is not None and s["match_pct"] < MIN_MATCH_PCT:
        warnings.append(f"매칭률 {s['match_pct']}% (< {MIN_MATCH_PCT}%) — 관제 미수집 기간이 있는지 확인")
    if s["raw_events"] != s["fact_events"]:
        warnings.append(f"관제 이벤트 raw {s['raw_events']} ≠ fact {s['fact_events']}")
    if s["mart_arrivals"] != s["fact_arrivals"]:
        warnings.append(f"mart 입항 합계 {s['mart_arrivals']} ≠ fact {s['fact_arrivals']}")
    if s["missing_days"] > MAX_MISSING_DAYS:
        warnings.append(f"mart에서 빠진 날 {s['missing_days']}일 — 모니터링 18번으로 날짜 확인")
    return warnings
