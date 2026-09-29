import uuid
import logging
from datetime import datetime

from psycopg2.extras import execute_values

from db.postgres import get_connection


logger = logging.getLogger(__name__)

# =========================================================
# Request 테이블 생성
# =========================================================
def make_request_id(
    source_type: str,
    port_code: str,
    start_date: str,
    end_date: str,
    date_type: str,
    page_no: int,
    date: datetime
):
    """
        API 요청 단위를 구분하기 위한 request_id 생성.
    """
    return (
        f"{source_type}_"
        f"{port_code}_"
        f"{start_date}_"
        f"{end_date}_"
        f"{date_type}_"
        f"{page_no}_"
        f"{date}_"
        f"{uuid.uuid4().hex[:8]}"
    )



def insert_api_request(
    run_id:int,
    source_type: str,
    port_code: str,
    start_date: str,
    end_date: str,
    date_type='I',
    page_no=1,
    num_of_rows=50
):
    conn = get_connection()
    
    try:
        with conn.cursor() as cursor:
    
            request_date = datetime.now().strftime("%Y%m%dT%H%M%S")
            request_id = make_request_id(
                source_type=source_type,
                port_code=port_code,
                start_date=start_date,
                end_date= end_date,
                date_type=date_type,
                page_no=page_no,
                date = request_date,
            )
                                        
            sql="""
                insert into audit.api_request (
                    request_id, 
                    source_type,
                    prt_ag_cd,
                    start_date,
                    end_date,
                    date_type,
                    page_no,
                    num_of_rows,
                    run_id
                )
                values(
                    %s,%s,%s,%s,%s,
                    %s,%s,%s,%s
                )
                RETURNING 
                    api_request_id,
                    request_id
            """
            
            cursor.execute(
                sql,
                (request_id,
                source_type,
                port_code,
                start_date,
                end_date,
                date_type,
                page_no,
                num_of_rows,
                run_id
                )
            )
            result = cursor.fetchone()
            
        conn.commit()
        logger.info(
            "api_request 생성 완료 - api_request_id=%s, request_id=%s",
            result[0],
            result[1]
        )
        return result
    except Exception:
            conn.rollback()
    
            logger.exception(
                "api_request insert 실패 - request_id=%s",
                request_id
            )
    
            raise
    
    finally:
        conn.close()
    
    
def update_api_request_status(
    api_request_id: int,
    total_count: int | None = None,
    total_pages: int | None = None,
    response_count: int | None=None,
    detail_count:int | None=None,
    status: str = "SUCCESS",
    error_message: str | None = None
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:

            sql = """
                UPDATE audit.api_request
                SET 
                    response_count=%s,
                    total_count = %s,
                    total_page = %s,
                    detail_count=%s,
                    status = %s,
                    error_message = %s,
                    request_finished_at = CURRENT_TIMESTAMP
                WHERE api_request_id = %s
            """

            cursor.execute(
                sql,
                (   
                    response_count,
                    total_count,
                    total_pages,
                    detail_count,
                    status,
                    error_message,
                    api_request_id
                )
            )

        conn.commit()

    except Exception:
        conn.rollback()

        logger.exception(
            "api_request 상태 업데이트 실패 - api_request_id=%s",
            api_request_id
        )

        raise

    finally:
        conn.close()
        
        
        
        
# strftime("%Y%m%d")

## 조회 필요조건 : 항만청코드 , 검색시작일 종료일 
def get_list_for_control(
    run_id : int
):
    
    conn = get_connection()
    
    sql="""
        SELECT DISTINCT
            msc.prt_ag_cd,
            ar.start_date,
            ar.end_date
        FROM raw.mof_ship_call msc
        JOIN audit.api_request ar
            ON ar.api_request_id = msc.request_id
        WHERE ar.run_id = %s
        ORDER BY msc.prt_ag_cd;
    """
    with conn.cursor() as cursor:
        try:
            cursor.execute(
                sql,
                (run_id,)
            )
            ship_call_list = cursor.fetchall()
            logger.info("ship_call 데이터 조회 성공! ")
            
            return ship_call_list
        
        except Exception as e:
            logger.warning(" ship_call 데이터 조회 중 오류 발생 %s",str(e))
            raise
        finally:
            conn.close()    
