import logging
import os
import time
from pathlib import Path

import psycopg2
from config.setting import SQL_DIR
from db.postgres import get_connection

logger = logging.getLogger(__name__)
FACT_SHIP_CALL_SQL = "fact_ship_call_load.sql"
FACT_CONTROL_EVENT_SQL = "fact_control_event_load.sql"
VESSEL_KIND_SQL="check_vssl_kind_update.sql"
# 선박 종류 데이터 새로 생긴거 있는지 없는지 체크 -> 있으면 insert, 없으면 pass

def _run_sql_file(conn, filename: str) -> float:
    """SQL 파일 하나 실행 후 걸린 시간(초)을 돌려줌. 실패하면 rollback 후 예외를 다시 올림."""
    sql = (SQL_DIR / filename).read_text(encoding="utf-8")
    logger.info("%s 실행", filename)
    start = time.perf_counter()
    try:
        with conn.cursor() as cur:
            cur.execute(sql)
        conn.commit()
    except Exception:
        conn.rollback()
        logger.exception("%s 실행 중 오류 발생", filename)
        raise
    elapsed = round(time.perf_counter() - start, 1)
    logger.info("%s 완료 (%.1f초)", filename, elapsed)
    return elapsed

def check_vssl_kind_update(conn) -> list[tuple]:
    logger.info("check_vssl_kind_update.sql 실행")
    filename= VESSEL_KIND_SQL
    """선종 코드 자동 추가 + raw 이름 변경 감지. 바뀐 행 목록을 돌려줌."""
    sql = (SQL_DIR / filename).read_text(encoding="utf-8")
    try:
        with conn.cursor() as cur:
            cur.execute(sql)
            rows = cur.fetchall()
        conn.commit()
    except psycopg2.Error:
        conn.rollback()
        logger.exception("선종 코드 점검 실패 — 건너뛰고 적재 계속")
        return []

    if not rows:
        logger.info("선종 코드 변경 없음")
        return []
    for cd, nm, raw_nm, is_new in rows:
        if is_new:
            logger.warning("새 선종 추가: %s %s → 관제 대상 여부 판단 필요", cd, raw_nm)
        else:
            logger.warning("선종명 변경 감지: %s 코드표='%s' / raw='%s'", cd, nm, raw_nm)
    logger.info("선종 코드 변경 감지 완료. %d건", len(rows))
    return rows


# /* 확인 2: 관제 비대상 규칙 적용 시 미매칭 구분 */
# fact_ship_call_load 실행
def load_fact_ship_call():
    conn =get_connection()
    filename= FACT_SHIP_CALL_SQL
    try:
        changes = check_vssl_kind_update(conn)
        elapsed = _run_sql_file(conn, filename)
        return {"elapsed_sec" : elapsed,
                "vessel_kind_changes":[list(r) for r in changes]}

    finally:
        conn.close()
        
        
def load_fact_control_event():
    conn = get_connection()
    filename= FACT_CONTROL_EVENT_SQL
    
    try:
        elaspsed_sec  = _run_sql_file(conn,filename)
        return {"filename":filename,
                "elaspsed_sec": elaspsed_sec }
    finally:
        conn.close()
    
# fact_control_event_load  실행
# mart_port_dail_kpi_load 실행
# monitory으로 확인하기 
