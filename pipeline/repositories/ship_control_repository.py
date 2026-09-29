from repositories.api_request_repository import update_api_request_status

import json
import logging
from datetime import datetime
from collections import Counter
from config import setting
from db.postgres import get_connection
from psycopg2.extras import execute_values
from utils.utils import normalize_datetime,get_arrival_dt,is_changed,normalize_datetime_key



logger = logging.getLogger(__name__)

def save_ship_call_control_data(
    items:list[dict],
    total_count : int,
    api_request_id: int,
    total_pages: int
): 
    conn= get_connection()
    
    logger.info("save_ship_call_control 호출 : control_call=%s건/%s건 , request_id= %s",
                len(items),                
                total_count,
                api_request_id)
    
    
    response_count = len(items)
    detail_count = 0
    try:
        with conn.cursor() as cursor:
        # -----------------------------------------
        # 1. ship_control_call 부모 데이터 생성(관제데이터 부모)
        # -----------------------------------------
            control_rows = build_control_call_rows(items=items,api_request_id=api_request_id)
            logger.info("ship_control_call_rows 갯수 : %s", len(control_rows))
            
            duplicate_test(rows=control_rows)
            
            insert_ship_control = batch_upsert_control_call(
                cursor,
                control_rows
            )
            
            raw_id_map = build_raw_id_map(
                insert_ship_control=insert_ship_control
            )
            
            logger.info( "build_raw_id_map 첫 번째 값: %s",next(iter(raw_id_map.items()), None))
            # -----------------------------------------
            # detail row 생성
            # -----------------------------------------
            
            detail_rows = build_detail_rows(
                items,
                raw_id_map
            )
            logger.info("detail_rows %s건 생성완료",len(detail_rows))
            if detail_rows:
                insert_detail_event = upsert_control_detail_event(
                    rows= detail_rows,
                    cursor=cursor
                )
            else:
                insert_detail_event=[]
                logger.info("저장할 control_event detail 없음")
            
        
        conn.commit()
        response_count = len(items)
        detail_count = len(insert_detail_event)
        
        update_api_request_status(
            api_request_id=api_request_id,
            response_count=response_count,
            detail_count=detail_count,
            total_count=total_count,
            total_pages=total_pages
        )
        
        logger.info(
                    "관제정보 저장 완료 - control_call=%s건, detail=%s건",
                    response_count,
                    detail_count
                )
    
    except Exception as e:
        conn.rollback()
        try:
            update_api_request_status(
                            api_request_id=api_request_id,
                            total_count=total_count,
                            total_pages=total_pages,
                            response_count=len(items),
                            status="FAILED",
                            error_message=f"{type(e).__name__}: {str(e)}"
                        )
        except Exception:
            logger.exception(
                "FAILD 상태 기록 중 추가 오류 발생 - api-request-id= %s",
                api_request_id
            )

        logger.exception(
                    "save_ship_control_data 실패 - api_request_id=%s",
                    api_request_id
                )
        raise
    finally:
        conn.close()




def batch_upsert_control_call(
    cursor,
    rows
):
    logger.info("control_call %r건 저장시도",len(rows))
    
    sql = """
    INSERT INTO raw.mof_control_call
        (
            api_request_id,          -- 1
            prt_ag_cd,               -- 2
            prt_ag_nm,               -- 3
            etrypt_year,             -- 4
            etrypt_co,               -- 5
            clsgn,                   -- 6
            vssl_knd_cd,             -- 7
            vssl_knd_nm,             -- 8
            vssl_nm,                 -- 9
            vssl_grtg,               -- 10
            vssl_nlty_cd,            -- 11
            vssl_nlty_nm,            -- 12
            vssl_satmnt_ag_cd,       -- 13
            satmnt_etrypt_year,      -- 14
            satmnt_etrypt_co,        -- 15
            aprtf_etrypt_dt,         -- 16
            tkoff_dt,                -- 17
            harbor_entrps_cd,        -- 18
            harbor_entrps_nm,        -- 19
            raw_payload,             -- 20
            first_inserted_at        -- 21
        )
        VALUES %s
        ON CONFLICT(
            prt_ag_cd,
            etrypt_year,
            etrypt_co,
            clsgn,
            aprtf_etrypt_dt
        )
        DO UPDATE SET
            api_request_id = EXCLUDED.api_request_id,
            prt_ag_nm = EXCLUDED.prt_ag_nm,
            vssl_knd_cd = EXCLUDED.vssl_knd_cd,
            vssl_knd_nm = EXCLUDED.vssl_knd_nm,
            vssl_nm = EXCLUDED.vssl_nm,
            vssl_grtg = EXCLUDED.vssl_grtg,
            vssl_nlty_cd = EXCLUDED.vssl_nlty_cd,
            vssl_nlty_nm = EXCLUDED.vssl_nlty_nm,
            vssl_satmnt_ag_cd = EXCLUDED.vssl_satmnt_ag_cd,
            satmnt_etrypt_year = EXCLUDED.satmnt_etrypt_year,
            satmnt_etrypt_co = EXCLUDED.satmnt_etrypt_co,
            tkoff_dt = EXCLUDED.tkoff_dt,
            harbor_entrps_cd = EXCLUDED.harbor_entrps_cd,
            harbor_entrps_nm = EXCLUDED.harbor_entrps_nm,
            raw_payload = EXCLUDED.raw_payload,
            updated_at=CURRENT_TIMESTAMP
        RETURNING
            control_call_raw_id,
            prt_ag_cd,
            etrypt_year,
            etrypt_co,
            clsgn,
            aprtf_etrypt_dt
        ;
    
    """
    
    return execute_values(
        cursor,
        sql,
        rows,
        template="""
        (
            %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s::jsonb,
            CURRENT_TIMESTAMP
        )
        """,
        fetch=True
        
    )

def upsert_control_detail_event(
    rows,
    cursor
):
    
    sql = """
        INSERT INTO raw.mof_control_event
        (
            control_call_raw_id, 
            cntrl_nm, 
            etrypt_year, 
            etrypt_co, 
            comm_co, 
            cntrl_se, 
            cntrl_opert_dt, 
            fclty_cd, 
            fclty_sub_cd, 
            fclty_nm, 
            raw_payload, 
            first_inserted_at
        )
        VALUES %s
        ON CONFLICT(
            control_call_raw_id,
            comm_co
        )
        DO UPDATE SET
            cntrl_nm = EXCLUDED.cntrl_nm,
            etrypt_year = EXCLUDED.etrypt_year,
            etrypt_co = EXCLUDED.etrypt_co,
            cntrl_se = EXCLUDED.cntrl_se,
            cntrl_opert_dt = EXCLUDED.cntrl_opert_dt,
            fclty_cd = EXCLUDED.fclty_cd,
            fclty_sub_cd = EXCLUDED.fclty_sub_cd,
            fclty_nm = EXCLUDED.fclty_nm,
            raw_payload = EXCLUDED.raw_payload,
            updated_at = CURRENT_TIMESTAMP
        RETURNING
            control_event_raw_id,
            control_call_raw_id,
            comm_co
    """
    return execute_values(
            cursor,
            sql,
            rows,
            template="""
            ( 
            %s, %s, %s, %s, %s, 
            %s, %s, %s, %s, %s,
            %s::jsonb, CURRENT_TIMESTAMP)
            """,
            fetch=True
        )
    
def make_control_call_key(
    prt_ag_cd,
    etrypt_year,
    etrypt_co,
    clsgn,
    aprtf_etrypt_dt
):
    return (
        prt_ag_cd,
        etrypt_year,
        etrypt_co,
        clsgn,
        normalize_datetime_key(aprtf_etrypt_dt)
    )   
    
        
    
def build_raw_id_map(insert_ship_control):
    raw_id_map={}
    
    for(
        control_call_raw_id,
        prt_ag_cd,
        etrypt_year,
        etrypt_co,
        clsgn,
        aprtf_etrypt_dt
    ) in insert_ship_control:
        key = make_control_call_key(
            prt_ag_cd=prt_ag_cd,
            etrypt_year=etrypt_year,
            etrypt_co=etrypt_co,
            clsgn=clsgn,
            aprtf_etrypt_dt=aprtf_etrypt_dt
        )
        
        raw_id_map[key] = control_call_raw_id
        
    return raw_id_map
    
    
#     CONSTRAINT uq_mof_control_call
# UNIQUE (
#     prt_ag_cd,
#     etrypt_year,
#     etrypt_co,
#     clsgn,
#     aprtf_etrypt_dt
# )






def build_control_call_rows(
    items,
    api_request_id
):
    """
    API ship_control_call dict → DB INSERT용 tuple 변환
    """

    rows = []

    for item in items:

        rows.append((
            api_request_id,

            item.get("prtAgCd"),   #항구청코드
            item.get("prtAgNm"),   #항만명

            item.get("etryptYear"), #입항년도
            item.get("etryptCo"),   #입항횟수

            item.get("clsgn"),      #호출부호

            item.get("vsslKndCd"), #선박종류코드
            item.get("vsslKndNm"), #선박종류명
            item.get("vsslNm"),     #선박한글명
            item.get("vsslGrtg"),    #선박총톤수  
            
            item.get("vsslNltyCd"), #선박국적코드
            item.get("vsslNltyNm"), #선박국적명
            item.get("vsslSatmntAgCd"), #선박신고청코드
            item.get("satmntEtryptYear"), #신고입항년도
            item.get("satmntEtryptCo"), #신고입항횟수
            item.get("aprtfEtryptDt"), #기항지입항일시
            item.get("tkoffDt"), #출항일시
            item.get("harborEntrpsCd"), #항만업체코드
            item.get("harborEntrpsNm"), #항만업체명

            json.dumps(
                item,
                ensure_ascii=False
            )
        ))

    return rows

def build_detail_rows(
    items,
    raw_id_map
):
    rows = []
    for item in items:
        key = make_control_call_key(
            item.get("prtAgCd"),
            item.get("etryptYear"),
            item.get("etryptCo"),
            item.get("clsgn"),
            item.get("aprtfEtryptDt"),
            )
        logger.info("확인용 key : %s",key)
        
        if key not in raw_id_map:
            raise KeyError(
                f"raw_id_map에서 ship_control_call key를 찾을 수 없습니다: {key}")
        
        control_call_raw_id = raw_id_map[key]
        detail_count = 0
        for detail in item.get("details",[]):
            detail_count+=1
            rows.append((
                control_call_raw_id,
                detail.get("cntrlNm"),
                detail.get("etryptYear"),
                detail.get("etryptCo"),
                detail.get("commCo"),
                detail.get("cntrlSe"),
                detail.get("cntrlOpertDt"),
                detail.get("fcltyCd"),
                detail.get("fcltySubCd"),
                detail.get("fcltyNm"),
                json.dumps(
                    detail,
                    ensure_ascii=False
                )
            ))
        logger.info("control_call_id[%s]의 detail 개수 : %s",control_call_raw_id, detail_count)
    return rows


def duplicate_test(
    rows: list[tuple],
      
):
    keys = [
            (row[1],
             row[3],
             row[4],
             row[5],
             row[15] 
            )
            for row in rows
        ]
        
    counter = Counter(keys)
    duplicates = {
            key: count
            for key, count in counter.items()
            if count>1
        }
    if duplicates:
        for key, count in duplicates.items():
            duplicate_rows = [
                row
                for row in rows
                if (
                    row[1],
                    row[3],
                    row[4],
                    row[5],
                    row[15]
                ) == key
            ]

            logger.error(
                "배치 내부 중복 발견 - key=%s, count=%s, rows=%s",
                key,
                count,
                duplicate_rows
            )

        raise ValueError(
            f"ship_control_call 배치 내부 중복 발견: {duplicates}"
        )
