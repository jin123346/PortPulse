import logging
import os
import time
from pathlib import Path

import psycopg2
from config.setting import SQL_DIR
from db.postgres import get_connection

logger = logging.getLogger(__name__)
MART_LOAD_SQL="mart_port_daily_kpi_load.sql"

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

def load_mart_data():
    conn = get_connection()
    filename = MART_LOAD_SQL

    try:
        elasped_sec= _run_sql_file(conn,filename)

        return {"file":filename,
                "elapsed_sec":elasped_sec}
    finally:
        conn.close()