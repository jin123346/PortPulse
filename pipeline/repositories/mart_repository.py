import logging
import os
import time
from pathlib import Path

import psycopg2
from config.setting import SQL_DIR
from db.postgres import get_connection

logger = logging.getLogger(__name__)


def load_mart_data():
    conn = get_connection()
    sql = (SQL_DIR / "mart_port_daily_kpi_load.sql").read_text(encoding="utf-8")

    try:
        with conn.cursor() as cur:
            logger.info("mart_port_daily_kpi_load.sql 실행")
            cur.execute(sql)
        conn.commit()
        logger.info("mart_port_daily_kpi_load.sql 완료")
    except Exception as e:
        logger.error("mart_port_daily_kpi_load.sql 실행 중 오류 발생: %s", e)
        conn.rollback()
        raise
    finally:
        conn.close()