import logging
import os
import time
from pathlib import Path

import psycopg2
from config.setting import SQL_DIR
from db.postgres import get_connection

logger = logging.getLogger(__name__)

# 선박 종류 데이터 새로 생긴거 있는지 없는지 체크 -> 있으면 insert, 없으면 pass

def check_vssl_kind_update(conn) -> list[tuple]:
    logger.info("check_vssl_kind_update.sql 실행")

    """선종 코드 자동 추가 + raw 이름 변경 감지. 바뀐 행 목록을 돌려줌."""
    sql = (SQL_DIR / "check_vssl_kind_update.sql").read_text(encoding="utf-8")
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
    sql = (SQL_DIR / "fact_ship_call_load.sql").read_text(encoding="utf-8")
    
    try:
        check_vssl_kind_update(conn)
        with conn.cursor() as cur:
            logger.info("fact_ship_call_load.sql 실행")
            cur.execute(sql)
        conn.commit()
        logger.info("fact_ship_call_load.sql 완료")
    except Exception as e:
        logger.error("fact_ship_call_load.sql 실행 중 오류 발생: %s", e)
        conn.rollback()
        raise
    finally:
        conn.close()
        
        
def load_fact_control_event():
    conn = get_connection()
    sql = (SQL_DIR / "fact_control_event_load.sql").read_text(encoding="utf-8")
    
    try:
        with conn.cursor() as cur:
            logger.info("fact_control_event_load.sql 실행")
            cur.execute(sql)
        conn.commit()
        logger.info("fact_control_event_load.sql 완료")
    except Exception as e:
        logger.error("fact_control_event_load.sql 실행 중 오류 발생: %s", e)
        conn.rollback()
        raise
    finally:
        conn.close()
    
# fact_control_event_load  실행
# mart_port_dail_kpi_load 실행
# monitory으로 확인하기 
