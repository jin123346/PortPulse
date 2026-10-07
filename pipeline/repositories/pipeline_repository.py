import json
import logging
from datetime import datetime

from psycopg2.extras import execute_values
from collections import Counter
from db.postgres import get_connection


logger = logging.getLogger(__name__)

def create_pipeline_run(
    pipeline_name : str,
    start_date : str,
    end_date : str,
    trigger: str
):
    conn = get_connection()
    
    try:
        with conn.cursor() as cursor:
            sql="""
                WITH new_run AS (
                    SELECT nextval('audit.pipeline_run_run_id_seq') AS run_id
                )
                INSERT INTO audit.pipeline_run (
                    run_id,
                    pipeline_name,
                    run_key,
                    start_date,
                    end_date,
                    trigger,
                    status
                )
                SELECT
                    run_id,
                    %s,
                    %s || '_' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '_' || run_id,
                    %s,
                    %s,
                    %s,
                    'RUNNING'
                FROM new_run
                RETURNING
                    run_id,
                    run_key;
            """
            
            cursor.execute(
                sql,
                (
                    pipeline_name,
                    pipeline_name,
                    start_date,
                    end_date,
                    trigger
                )
            )

            run_id, run_key = cursor.fetchone()
        conn.commit()
        
        logger.info(
            "pipeline_run 생성완료 - run_id = %s, pipeline_name=%s",
            run_id,
            pipeline_name
        )
        
        return run_id,run_key
    
    except Exception:
        conn.rollback()
        logger.exception("pipeline 생성실패")
        raise
    finally:
        conn.close()
    
    
    
# RUNNING / SUCCESS / PARTIAL_SUCCESS / FAILED / (CANCELLED, SKIPPED, TIMEOUT)
# if failure_count == 0:
#     status = "SUCCESS"

# elif success_count > 0 or empty_count > 0:
#     status = "PARTIAL_SUCCESS"

# else:
#     status = "FAILED"


def update_pipeline_run_status(
    run_id: int,
    status: str,
    error_message: str | None = None
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                UPDATE audit.pipeline_run
                SET
                    status = %s,
                    error_message = %s,
                    finished_at = CURRENT_TIMESTAMP
                WHERE run_id = %s
                """,
                (
                    status,
                    error_message,
                    run_id
                )
            )

        conn.commit()

    except Exception:
        conn.rollback()
        logger.exception(
            "pipeline_run 상태 업데이트 실패 - run_id=%s",
            run_id
        )
        raise

    finally:
        conn.close()
        
        
def get_pipeline_run(run_id):
    conn = get_connection()
    
    try:
        with conn.cursor() as cursor:
            result = cursor.execute(
                """
                select run_id,pipeline_name,run_key,start_date,end_date
                from audit.pipeline_run
                WHERE run_id = %s
                """,
                (
                    run_id,
                )
            )
            return cursor.fetchone()

        
    except Exception:
        logger.exception(
            "pipeline_run 조회 실패 - run_id=%s",
            run_id
        )
        raise

    finally:
        conn.close()
      
        
