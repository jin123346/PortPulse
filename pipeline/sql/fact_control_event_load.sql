/* =====================================================================
   fact.fact_control_event 적재

   [실행 전 확인]
   - fact_control_event_setup.sql 1회 실행 완료
   - 스크립트 전체 실행(Alt+X). Auto-Commit 켜짐/꺼짐 모두 동작
   - fact_ship_call 적재와 순서 상관없음 (서로 참조하지 않음)

   [동작]
   - raw.mof_control_event 기준 UPSERT (control_event_raw_id)
   - 값이 바뀐 행만 UPDATE
   - raw에서 사라진 이벤트는 fact에서도 삭제 (raw 관제 삭제 시 CASCADE로 함께 지워지는 경우 대비)
   - 다음 이벤트: 같은 control_call_raw_id 안에서 comm_co 순서, 같으면 시각·raw id 순
   - 처음 보는 이벤트 코드는 master.dim_control_event_type에 '기타'로 자동 추가
   ===================================================================== */

/* 시간대 고정 (event_dt 등은 한국 시간 timestamp) */
SET TIME ZONE 'Asia/Seoul';

BEGIN;

/* 1. 새 이벤트 코드를 dim에 추가 (기존 코드는 건드리지 않음) */
INSERT INTO master.dim_control_event_type (event_code, event_name, event_group, note)
SELECT cntrl_se, MODE() WITHIN GROUP (ORDER BY cntrl_nm), '기타', '자동 추가: 분류 확인 필요'
FROM raw.mof_control_event
WHERE cntrl_se IS NOT NULL AND cntrl_nm IS NOT NULL
GROUP BY cntrl_se
ON CONFLICT (event_code) DO NOTHING;


/* 2. 이벤트 + 다음 이벤트 */
DROP TABLE IF EXISTS tmp_control_event;
CREATE TEMP TABLE tmp_control_event AS
SELECT
    e.control_event_raw_id,
    e.control_call_raw_id,
    e.comm_co                                       AS event_seq,
    e.cntrl_se                                      AS event_code,
    e.cntrl_nm                                      AS event_name,
    e.cntrl_opert_dt                                AS event_dt,
    e.fclty_cd                                      AS facility_code,
    e.fclty_sub_cd                                  AS facility_sub_code,
    e.fclty_nm                                      AS facility_name,
    (ROW_NUMBER() OVER w = 1)                       AS is_first_event,
    (LEAD(e.control_event_raw_id) OVER w IS NULL)   AS is_last_event,
    LEAD(e.control_event_raw_id) OVER w             AS next_event_raw_id,
    LEAD(e.cntrl_opert_dt)       OVER w             AS next_event_dt
FROM raw.mof_control_event e
WINDOW w AS (
    PARTITION BY e.control_call_raw_id
    ORDER BY e.comm_co NULLS LAST, e.cntrl_opert_dt NULLS LAST, e.control_event_raw_id
);

ANALYZE tmp_control_event;


/* 3. raw에서 사라진 이벤트 삭제 */
DELETE FROM fact.fact_control_event f
WHERE NOT EXISTS (
    SELECT 1 FROM tmp_control_event t
    WHERE t.control_event_raw_id = f.control_event_raw_id
);


/* 4. UPSERT */
INSERT INTO fact.fact_control_event AS f (
    control_event_raw_id,
    control_call_raw_id,
    event_seq,
    event_code,
    event_name,
    event_dt,
    facility_code,
    facility_sub_code,
    facility_name,
    is_first_event,
    is_last_event,
    next_event_raw_id,
    next_event_dt,
    minutes_to_next
)
SELECT
    control_event_raw_id,
    control_call_raw_id,
    event_seq,
    event_code,
    event_name,
    event_dt,
    facility_code,
    facility_sub_code,
    facility_name,
    is_first_event,
    is_last_event,
    next_event_raw_id,
    next_event_dt,
    (EXTRACT(EPOCH FROM (next_event_dt - event_dt)) / 60)::bigint AS minutes_to_next
FROM tmp_control_event
ON CONFLICT (control_event_raw_id)
DO UPDATE SET
    control_call_raw_id = EXCLUDED.control_call_raw_id,
    event_seq           = EXCLUDED.event_seq,
    event_code          = EXCLUDED.event_code,
    event_name          = EXCLUDED.event_name,
    event_dt            = EXCLUDED.event_dt,
    facility_code       = EXCLUDED.facility_code,
    facility_sub_code   = EXCLUDED.facility_sub_code,
    facility_name       = EXCLUDED.facility_name,
    is_first_event      = EXCLUDED.is_first_event,
    is_last_event       = EXCLUDED.is_last_event,
    next_event_raw_id   = EXCLUDED.next_event_raw_id,
    next_event_dt       = EXCLUDED.next_event_dt,
    minutes_to_next     = EXCLUDED.minutes_to_next,
    updated_at          = CURRENT_TIMESTAMP
WHERE (
    f.control_call_raw_id, f.event_seq, f.event_code, f.event_name, f.event_dt,
    f.facility_code, f.facility_sub_code, f.facility_name,
    f.is_first_event, f.is_last_event, f.next_event_raw_id, f.next_event_dt, f.minutes_to_next
) IS DISTINCT FROM (
    EXCLUDED.control_call_raw_id, EXCLUDED.event_seq, EXCLUDED.event_code, EXCLUDED.event_name, EXCLUDED.event_dt,
    EXCLUDED.facility_code, EXCLUDED.facility_sub_code, EXCLUDED.facility_name,
    EXCLUDED.is_first_event, EXCLUDED.is_last_event, EXCLUDED.next_event_raw_id, EXCLUDED.next_event_dt, EXCLUDED.minutes_to_next
);

COMMIT;
