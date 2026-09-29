import json
import logging
from datetime import datetime

from psycopg2.extras import execute_values
from collections import Counter
from repositories.api_request_repository import update_api_request_status
from db.postgres import get_connection
from utils.utils import normalize_datetime,get_arrival_dt,is_changed

logger = logging.getLogger(__name__)


# =========================================================
# 전체 저장 진입점
# =========================================================

def save_ship_calls(
    ship_calls: list[dict],
    api_request_id: str,
    total_count: int,
    total_pages: int
):
    """
    ship_call 및 하위 detail 데이터를 하나의 transaction으로 저장한다.
    """

    conn = get_connection()

    logger.info(
        "save_ship_calls 호출: ship_calls=%s건, request_id=%s",
        len(ship_calls),
        api_request_id
    )
    response_count =len(ship_calls)
    detail_count=0

    try:
        with conn.cursor() as cursor:

            # -----------------------------------------
            # 1. ship_call 부모 데이터 생성
            # -----------------------------------------
            ship_call_rows = build_ship_call_rows(
                ship_calls,
                api_request_id
            )
            logger.info("ship_call_rows 갯수 : %s", len(ship_call_rows))
            # 1-2. 중복검사
            keys = [
                (
                    row[1],  # prt_ag_cd
                    row[3],  # etrypt_yr
                    row[4],  # etrypt_co
                    row[5],  # clsgn
                )
                for row in ship_call_rows
            ]

            counter = Counter(keys)

            duplicates = {
                key: count
                for key, count in counter.items()
                if count > 1
            }

            if duplicates:
                logger.warning(
                    "배치 내부 중복 발견 - duplicates=%s",
                    duplicates
                )
            for key, count in duplicates.items():
                duplicated_rows = [
                    row
                    for row in ship_call_rows
                    if (
                        row[1],  # prt_ag_cd
                        row[3],  # etrypt_yr
                        row[4],  # etrypt_co
                        row[5],  # clsgn
                    ) == key
                ]

                logger.warning(
                    "중복 키=%s, count=%s, rows=%s",
                    key,
                    count,
                    duplicated_rows
                )

            # -----------------------------------------
            # 2. ship_call UPSERT
            # -----------------------------------------
            inserted_ship_calls = batch_upsert_ship_calls(
                cursor,
                ship_call_rows
            )

            logger.info(
                "ship_call %s건 저장/갱신 완료",
                len(inserted_ship_calls)
            )

            # -----------------------------------------
            # 3. API 데이터 ↔ DB raw_id 매핑
            # -----------------------------------------
            raw_id_map = build_raw_id_map(
                inserted_ship_calls
            )
            logger.info(
                "raw_id_map 키맵 : %s",
                raw_id_map
            )

            # -----------------------------------------
            # 4. detail row 생성
            # -----------------------------------------
            detail_rows = build_detail_rows(
                ship_calls,
                raw_id_map
            )

            logger.info(
                "detail_rows %s건 생성 완료",
                len(detail_rows)
            )

            # -----------------------------------------
            # 5. detail 신규/변경 처리
            # -----------------------------------------
            upsert_ship_call_details(
                cursor,
                detail_rows
            )
           
        conn.commit()
         # -----------------------------------------
        # 6. Request 요청 업데이트 
        # -----------------------------------------
        response_count=  len(ship_calls)
        detail_count = len(detail_rows)
        
        update_api_request_status(
            api_request_id=api_request_id,
            response_count=response_count,
            detail_count=detail_count,
            total_count=total_count,
            total_pages=total_pages,
            status="SUCCESS"
        )
        
        logger.info(
            "저장 완료 - ship_call=%s건, detail=%s건",
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
                response_count=len(ship_calls),
                status="FAILED",
                error_message=f"{type(e).__name__}: {str(e)}"
            )
        except Exception:
            logger.exception(
                "FAILED 상태 기록 중 추가 오류 발생 - api_request_id=%s",
                api_request_id
            )

        logger.exception(
            "save_ship_calls 실패 - api_request_id=%s",
            api_request_id
        )

        raise

    finally:
        conn.close()


# =========================================================
# ship_call
# =========================================================

def build_ship_call_rows(
    ship_calls,
    request_id
):
    """
    API ship_call dict → DB INSERT용 tuple 변환
    """

    rows = []

    for ship_call in ship_calls:

        arrival_dt = get_arrival_dt(ship_call)

        rows.append((
            request_id,

            ship_call.get("prtAgCd"),
            ship_call.get("prtAgNm"),

            ship_call.get("etryptYear"),
            ship_call.get("etryptCo"),

            ship_call.get("clsgn"),

            ship_call.get("vsslNm"),

            ship_call.get("vsslNltyCd"),
            ship_call.get("vsslNltyNm"),

            ship_call.get("vsslKndCd"),
            ship_call.get("vsslKndNm"),

            ship_call.get("etryptPurpsCd"),
            ship_call.get("etryptPurpsNm"),

            ship_call.get("frstDpmprtNatPrtCd"),
            ship_call.get("frstDpmprtPrtNm"),

            ship_call.get("prvsDpmprtNatPrtCd"),
            ship_call.get("prvsDpmprtPrtNm"),

            ship_call.get("nxlnptNatPrtCd"),
            ship_call.get("nxlnptPrtNm"),

            ship_call.get("dstnNatPrtCd"),
            ship_call.get("dstnPrtNm"),

            arrival_dt,

            json.dumps(
                ship_call,
                ensure_ascii=False
            )
        ))

    return rows


def batch_upsert_ship_calls(
    cursor,
    ship_call_rows
):
    """
    ship_call 부모 데이터를 batch UPSERT한다.
    """

    logger.info(
        "ship_call_rows %s건 저장 시도",
        len(ship_call_rows)
    )

    
    sql = """
        INSERT INTO raw.mof_ship_call (
            request_id,
            prt_ag_cd,
            prt_ag_nm,
            etrypt_yr,
            etrypt_co,
            clsgn,
            vssl_nm,
            vssl_nlty_cd,
            vssl_nlty_nm,
            vssl_knd_cd,
            vssl_knd_nm,
            etrypt_purps_cd,
            etrypt_purps_nm,
            frst_dpmprt_nat_prt_cd,
            frst_dpmprt_prt_nm,
            prvs_dpmprt_nat_prt_cd,
            prvs_dpmprt_prt_nm,
            nxlnpt_nat_prt_cd,
            nxlnpt_prt_nm,
            dstn_nat_prt_cd,
            dstn_prt_nm,
            arrival_dt,
            raw_payload,
            first_extracted_at,
            update_extracted_at
        )
        VALUES %s
        ON CONFLICT (
            prt_ag_cd,
            etrypt_yr,
            etrypt_co,
            clsgn
        )
        DO UPDATE SET
            request_id = EXCLUDED.request_id,
            raw_payload = EXCLUDED.raw_payload,
            update_extracted_at = CURRENT_TIMESTAMP
        RETURNING
            raw_id,
            prt_ag_cd,
            etrypt_yr,
            etrypt_co,
            clsgn
    """

    return execute_values(
        cursor,
        sql,
        ship_call_rows,
        template="""
            (
                %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s,
                %s, %s, %s::jsonb,
                CURRENT_TIMESTAMP,
                CURRENT_TIMESTAMP
            )
        """,
        fetch=True
    )


def build_raw_id_map(inserted_ship_calls):
    raw_id_map = {}

    for (
        raw_id,
        prt_ag_cd,
        etrypt_yr,
        etrypt_co,
        clsgn,
    ) in inserted_ship_calls:

        key = (
            str(prt_ag_cd),
            str(etrypt_yr),
            str(etrypt_co),
            str(clsgn),
        )

        raw_id_map[key] = raw_id

    return raw_id_map


# =========================================================
# ship_call_detail
# =========================================================

def build_detail_rows(
    ship_calls,
    raw_id_map
):
    """
    ship_call 내부 details를 detail 테이블 저장용 tuple로 변환한다.
    """

    rows = []

    for ship_call in ship_calls:

        key = (
            ship_call.get("prtAgCd"),
            ship_call.get("etryptYear"),
            ship_call.get("etryptCo"),
            ship_call.get("clsgn"),
        )
        logger.info(
            "확인용 key : %s",
            key
        )

        if key not in raw_id_map:
            raise KeyError(
                f"raw_id_map에서 ship_call key를 찾을 수 없습니다: {key}"
            )

        ship_call_raw_id = raw_id_map[key]

        for detail in ship_call.get("details", []):

            rows.append((
                ship_call_raw_id,                 # 0
                detail.get("reqstSeNm"),          # 1
                detail.get("etryndNm"),           # 2
                detail.get("etryptDt"),           # 3
                detail.get("tkoffDt"),            # 4
                detail.get("ibobprtNm"),          # 5
                detail.get("laidupFcltyCd"),      # 6
                detail.get("laidupFcltySubCd"),   # 7
                detail.get("laidupFcltyNm"),      # 8
                detail.get("tugYn"),              # 9
                detail.get("piltgYn"),            # 10
                detail.get("ldadngFrghtClCd"),    # 11
                detail.get("ldadngTon"),          # 12
                detail.get("trnpdtTon"),          # 13
                detail.get("landngFrghtTon"),     # 14
                detail.get("ldFrghtTon"),         # 15
                detail.get("grtg"),               # 16
                detail.get("intrlGrtg"),          # 17
                detail.get("satmntEntrpsNm"),     # 18
                detail.get("crewCo"),             # 19
                detail.get("koranCrewCo"),        # 20
                detail.get("frgnrCrewCo"),        # 21
                detail.get("mrNum"),              # 22
                detail.get("tkoffPrrrnDt"),       # 23
                detail.get("dstnEtryptDt"),       # 24
                json.dumps(
                    detail,
                    ensure_ascii=False
                )                                 # 25
            ))

    return rows


# =========================================================
# detail 신규/변경 판단
# =========================================================

def upsert_ship_call_details(
    cursor,
    detail_rows
):
    """
    ship_call_raw_id + etrynd_nm 기준으로

    1. 신규 → INSERT
    2. 동일 → SKIP
    3. 변경 → HISTORY 저장 후 UPDATE
    """

    inserted_count = 0
    updated_count = 0
    unchanged_count = 0

    for row in detail_rows:

        ship_call_raw_id = row[0]
        etrynd_nm = row[2]
        reqst_se_nm = row[1]
        new_raw_payload = row[-1]

        cursor.execute(
            """
            SELECT
                detail_raw_id,
                raw_payload
            FROM raw.mof_ship_call_detail
            WHERE ship_call_raw_id = %s
            AND etrynd_nm = %s
            AND reqst_se_nm = %s
            """,
            (
                ship_call_raw_id,
                etrynd_nm,
                reqst_se_nm
            )
        )

        existing_row = cursor.fetchone()

        # -----------------------------------------
        # 신규
        # -----------------------------------------
        if existing_row is None:

            insert_detail(
                cursor,
                row
            )

            inserted_count += 1

            logger.info(
                "detail 신규 저장 - ship_call_raw_id=%s, etrynd_nm=%s",
                ship_call_raw_id,
                etrynd_nm
            )

            continue

        detail_id, existing_raw_payload = existing_row

        # -----------------------------------------
        # 기존 데이터와 동일
        # -----------------------------------------
        if not is_changed(
            existing_raw_payload,
            new_raw_payload
        ):

            unchanged_count += 1

            logger.debug(
                "detail 변경 없음 - detail_id=%s, etrynd_nm=%s , reqst_se_nm=%s",
                detail_id,
                etrynd_nm,
                reqst_se_nm
            )

            continue

        # -----------------------------------------
        # 변경됨
        # -----------------------------------------
        update_detail(
            cursor=cursor,
            detail_id=detail_id,
            new_row=row,
            old_payload=existing_raw_payload
        )

        updated_count += 1

        logger.info(
            "detail 변경 저장 - detail_id=%s, etrynd_nm=%s, reqst_se_nm=%s",
            detail_id,
            etrynd_nm,
            reqst_se_nm
        )

    logger.info(
        "detail 처리 결과 - 신규=%s / 변경=%s / 동일=%s",
        inserted_count,
        updated_count,
        unchanged_count
    )


# =========================================================
# detail INSERT
# =========================================================

def insert_detail(
    cursor,
    detail_row
):
    """
    신규 detail 단건 INSERT
    """

    sql = """
        INSERT INTO raw.mof_ship_call_detail (
            ship_call_raw_id,

            reqst_se_nm,
            etrynd_nm,

            etrypt_dt,
            tkoff_dt,

            ibobprt_nm,

            laidup_fclty_cd,
            laidup_fclty_sub_cd,
            laidup_fclty_nm,

            tug_yn,
            piltg_yn,

            ldadng_frght_cl_cd,

            ldadng_ton,
            trnpdt_ton,
            landng_frght_ton,
            ld_frght_ton,

            grtg,
            intrl_grtg,

            satmnt_entrps_nm,

            crew_co,
            koran_crew_co,
            frgnr_crew_co,

            mr_num,

            tkoff_prrrn_dt,
            dstn_etrypt_dt,

            raw_payload,

            first_created_at,
            updated_at
        )
        VALUES (
            %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s,
            %s::jsonb,
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
        )
    """

    cursor.execute(
        sql,
        detail_row
    )


# =========================================================
# detail UPDATE + HISTORY
# =========================================================

def update_detail(
    cursor,
    detail_id,
    new_row,
    old_payload
):
    """
    변경 전 데이터를 history에 저장한 뒤
    detail 현재값을 최신 데이터로 UPDATE한다.
    """

    # -----------------------------------------
    # 1. History 저장
    # -----------------------------------------
    insert_detail_history(
        cursor=cursor,
        detail_id=detail_id,
        etrynd_nm=new_row[2],
        old_payload=old_payload,
        new_payload=new_row[-1]
    )

    # -----------------------------------------
    # 2. 현재 detail 최신화
    # -----------------------------------------
    sql = """
        UPDATE raw.mof_ship_call_detail
        SET
            reqst_se_nm = %s,

            etrypt_dt = %s,
            tkoff_dt = %s,

            ibobprt_nm = %s,

            laidup_fclty_cd = %s,
            laidup_fclty_sub_cd = %s,
            laidup_fclty_nm = %s,

            tug_yn = %s,
            piltg_yn = %s,

            ldadng_frght_cl_cd = %s,

            ldadng_ton = %s,
            trnpdt_ton = %s,
            landng_frght_ton = %s,
            ld_frght_ton = %s,

            grtg = %s,
            intrl_grtg = %s,

            satmnt_entrps_nm = %s,

            crew_co = %s,
            koran_crew_co = %s,
            frgnr_crew_co = %s,

            mr_num = %s,

            tkoff_prrrn_dt = %s,
            dstn_etrypt_dt = %s,

            raw_payload = %s::jsonb,

            updated_at = CURRENT_TIMESTAMP

        WHERE detail_raw_id = %s
    """

    cursor.execute(
        sql,
        (
            new_row[1],      # reqst_se_nm

            new_row[3],      # etrypt_dt
            new_row[4],      # tkoff_dt

            new_row[5],      # ibobprt_nm

            new_row[6],      # laidup_fclty_cd
            new_row[7],      # laidup_fclty_sub_cd
            new_row[8],      # laidup_fclty_nm

            new_row[9],      # tug_yn
            new_row[10],     # piltg_yn

            new_row[11],     # ldadng_frght_cl_cd

            new_row[12],     # ldadng_ton
            new_row[13],     # trnpdt_ton
            new_row[14],     # landng_frght_ton
            new_row[15],     # ld_frght_ton

            new_row[16],     # grtg
            new_row[17],     # intrl_grtg

            new_row[18],     # satmnt_entrps_nm

            new_row[19],     # crew_co
            new_row[20],     # koran_crew_co
            new_row[21],     # frgnr_crew_co

            new_row[22],     # mr_num

            new_row[23],     # tkoff_prrrn_dt
            new_row[24],     # dstn_etrypt_dt

            new_row[25],     # raw_payload

            detail_id
        )
    )


# =========================================================
# HISTORY
# =========================================================

def insert_detail_history(
    cursor,
    detail_id,
    etrynd_nm,
    old_payload,
    new_payload
):
    """
    detail 변경 전/후 데이터를 history 테이블에 저장한다.
    """

    if not isinstance(old_payload, str):
        old_payload = json.dumps(
            old_payload,
            ensure_ascii=False
        )

    if not isinstance(new_payload, str):
        new_payload = json.dumps(
            new_payload,
            ensure_ascii=False
        )

    sql = """
        INSERT INTO raw.mof_ship_call_detail_history (
            detail_id,
            etrynd_nm,
            old_payload,
            new_payload,
            changed_at
        )
        VALUES (
            %s,
            %s,
            %s::jsonb,
            %s::jsonb,
            CURRENT_TIMESTAMP
        )
    """

    cursor.execute(
        sql,
        (
            detail_id,
            etrynd_nm,
            old_payload,
            new_payload
        )
    )
    
    
    
# ========================================================
# 기능 보류 => 차이점 확인 
# ========================================================
def get_chaged_fields(old_payload, new_payload):
    changes = {}
    
    keys = set(old_payload.keys()) | set(new_payload.keys())
    
    for key in keys:
        old_value = old_payload.get(key)
        new_value = new_payload.get(key)

        if old_value != new_value:
            changes[key] = {
                "old": old_value,
                "new": new_value
            }

    return changes