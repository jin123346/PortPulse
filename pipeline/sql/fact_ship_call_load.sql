/* =====================================================================
   fact.fact_ship_call 적재 (v10)

   [실행 전 확인]
   - fact_ship_call_v5_setup.sql, v6_setup, v8_setup, v10_setup 1회 실행 완료
   - 스크립트 전체 실행(Alt+X). Auto-Commit 켜짐/꺼짐 모두 동작
   - 세션 시간대를 Asia/Seoul로 고정함 (스크립트 첫 문장)

   [매칭 규칙] 관제 1건 ↔ 신고 1건. 등급이 높은 근거부터 배정 (3번 섹션 참고)
     1 입항횟수 일치 + 6시간 이내      4 입항횟수 어긋남 + 시각 완전 일치
     2 같은 항구 + 시각 완전 일치      5 입항횟수 일치 + 6시간 초과 (출항 후 관제 제외)
     3 같은 권역 + 시각 완전 일치      6 같은 권역 + ±60분 근사
     ※ 입항횟수 일치 = 신고처 항구(COALESCE(vssl_satmnt_ag_cd, prt_ag_cd)) + 호출부호
                     + 관제 연도 + satmnt_etrypt_co
     ※ 권역 = master.dim_mof_port_code.region_key
     매칭 등급은 fact.control_match_priority에 저장

   [중복 신고 표시] 같은 호출부호의 신고가 입항시각 60분 이내이고 머문 기간이 겹치면
     suspected_duplicate = true (그룹 전체)
     duplicate_of_ship_call_raw_id = 대표 신고의 raw_id (대표가 아닌 신고만)
     대표: 관제가 매칭된 신고(등급 높은 순) → 없으면 raw_id가 가장 큰 신고
     표시만 하고 지우거나 합치지 않음

   [대표 입출항 시각] arrival_dt / departure_dt (+ *_source)
     1. 신고가 '최종'이면 신고 시각 (SHIP_CALL)
     2. 아니면 매칭된 관제의 실제 입출항 (CONTROL)
     3. 관제가 없으면 확정 전 신고 시각 (SHIP_CALL)
     출항은 대표 입항 이후인 값만 사용, stay_minutes = 출항 - 입항

   [변경 이력]
   v1  임시 테이블 분리 + ANALYZE (136초 → 1초 안팎), IS DISTINCT FROM
   v2  충돌 키 ship_call_raw_id
   v3  1순위 신고처 항구 기준, 신고 상세 동점 처리
   v4  권역 매칭, 임시 테이블 세션 단위
   v5  control_expected
   v6  입항횟수 어긋남+시각 일치, ±60분 근사, control_match_priority, 시간대 고정
   v7  관제 1:1 배정, 입항횟수 일치라도 6시간 초과면 시각 일치보다 후순위,
       출항 후 관제는 입항횟수 매칭에서 제외
   v8  중복 신고 표시 (suspected_duplicate, duplicate_of_ship_call_raw_id)
   v9  대표 입출항 시각: '최종' 신고 → 관제 실제 시각 → 확정 전 신고 순
       (확정 전 신고의 예정 시각 대신 관제 실측을 씀. 예: SPRING EURO 031)
   v10 gross_tonnage(총톤수), vessel_kind_cd(선종 코드) 추가 (mart 집계용)
   ===================================================================== */

/* 시간대 고정: aprtf_etrypt_dt(timestamp, 한국 시간)와 arrival_dt(timestamptz)를
   비교할 때 세션 시간대로 변환되므로, 서버 기본값(UTC)에서 실행하면 9시간 어긋남 */
SET TIME ZONE 'Asia/Seoul';

BEGIN;

/* =====================================================================
   1. 운항정보 상세: ship_call 한 건당 대표 입항/출항 정보
      (입항/출항 각각 최종 > 변경 > 최초, 같으면 updated_at 최신)
   ===================================================================== */
DROP TABLE IF EXISTS tmp_ship_detail;
CREATE TEMP TABLE tmp_ship_detail AS
WITH ranked_ship_detail AS (
    SELECT DISTINCT ON (d.ship_call_raw_id, d.etrynd_nm)
        d.ship_call_raw_id,
        d.etrynd_nm,
        d.etrypt_dt,
        d.tkoff_dt,
        d.reqst_se_nm,
        d.ibobprt_nm,
        d.grtg
    FROM raw.mof_ship_call_detail d
    ORDER BY
        d.ship_call_raw_id,
        d.etrynd_nm,
        CASE d.reqst_se_nm
            WHEN '최종' THEN 3
            WHEN '변경' THEN 2
            WHEN '최초' THEN 1
            ELSE 0
        END DESC,
        d.updated_at DESC,
        d.detail_raw_id DESC
)
SELECT
    ship_call_raw_id,
    MIN(etrypt_dt)   FILTER (WHERE etrynd_nm = '입항')::timestamp AS reported_arrival_dt,
    MAX(reqst_se_nm) FILTER (WHERE etrynd_nm = '입항')            AS arrival_request_type,
    MAX(tkoff_dt)    FILTER (WHERE etrynd_nm = '출항')::timestamp AS reported_departure_dt,
    MAX(reqst_se_nm) FILTER (WHERE etrynd_nm = '출항')            AS departure_request_type,
    MAX(ibobprt_nm)  FILTER (WHERE etrynd_nm = '입항')            AS ibobprt_nm,
    /* 총톤수: 입항 신고 → 없으면 출항 신고 (숫자가 아니거나 0이면 NULL) */
    COALESCE(
        MAX(NULLIF(CASE WHEN grtg ~ '^\s*[0-9]+(\.[0-9]+)?\s*$' THEN trim(grtg)::numeric END, 0)) FILTER (WHERE etrynd_nm = '입항'),
        MAX(NULLIF(CASE WHEN grtg ~ '^\s*[0-9]+(\.[0-9]+)?\s*$' THEN trim(grtg)::numeric END, 0)) FILTER (WHERE etrynd_nm = '출항')
    )                                                             AS reported_gross_tonnage
FROM ranked_ship_detail
GROUP BY ship_call_raw_id;


/* =====================================================================
   2. control_call별 관제 요약 (mof_control_event 1회 스캔)
      - actual_arrival_dt   : 가장 이른 입항
      - actual_departure_dt : 가장 늦은 출항
      - last_*              : comm_co가 가장 큰 마지막 관제 이벤트
   ===================================================================== */
DROP TABLE IF EXISTS tmp_control_summary;
CREATE TEMP TABLE tmp_control_summary AS
SELECT DISTINCT ON (control_call_raw_id)
    control_call_raw_id,
    MIN(cntrl_opert_dt) FILTER (WHERE cntrl_nm = '입항') OVER w AS actual_arrival_dt,
    MAX(cntrl_opert_dt) FILTER (WHERE cntrl_nm = '출항') OVER w AS actual_departure_dt,
    cntrl_nm        AS last_control_event,
    cntrl_opert_dt  AS last_control_event_dt,
    fclty_cd        AS last_facility_code,
    fclty_sub_cd    AS last_facility_sub_code,
    fclty_nm        AS last_facility_name
FROM raw.mof_control_event
WINDOW w AS (
    PARTITION BY control_call_raw_id
    ORDER BY comm_co DESC
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
)
ORDER BY control_call_raw_id, comm_co DESC;


/* =====================================================================
   3. ship_call ↔ control_call 매칭
      - 관제 1건에는 신고 1건만, 신고 1건에는 관제 1건만
      - 등급이 높은(숫자가 작은) 근거부터 차례로 배정
        1: 신고처 항구 + 신고 입항횟수 일치 + 입항시각 차이 6시간 이내
        2: 신고 입항횟수 없는 관제, 같은 항구 + 입항시각 완전 일치
        3: 신고 입항횟수 없는 관제, 같은 권역 + 입항시각 완전 일치
        4: 신고 입항횟수 있는 관제, 같은 권역 + 입항시각 완전 일치
           (관제의 입항횟수가 어긋난 건. 예: 20청우호 106 ↔ 관제 105)
        5: 신고처 항구 + 신고 입항횟수 일치 + 시각 차이 6시간 초과
           단, 관제 입항이 신고 출항보다 늦으면 제외 (출항한 배의 관제일 수 없음)
        6: 같은 권역 + 입항시각 ±60분 (근사)
      - 같은 등급 안에서는 시각 차이가 작은 쌍 우선
   ===================================================================== */

/* 3-1. 후보 (등급 1~5) */
DROP TABLE IF EXISTS tmp_match_cand;
CREATE TEMP TABLE tmp_match_cand AS
WITH ship AS (
    SELECT msc.raw_id, msc.prt_ag_cd, msc.clsgn, msc.etrypt_yr, msc.etrypt_co, msc.arrival_dt,
           COALESCE(pr.region_key, msc.prt_ag_cd) AS region_key,
           sd.reported_departure_dt
    FROM raw.mof_ship_call msc
    LEFT JOIN master.dim_mof_port_code pr ON pr.prt_ag_cd = msc.prt_ag_cd
    LEFT JOIN tmp_ship_detail sd          ON sd.ship_call_raw_id = msc.raw_id
),
ctrl AS (
    SELECT mcc.control_call_raw_id, mcc.prt_ag_cd, mcc.clsgn, mcc.etrypt_year,
           mcc.vssl_satmnt_ag_cd, mcc.satmnt_etrypt_co, mcc.aprtf_etrypt_dt,
           COALESCE(pr.region_key, mcc.prt_ag_cd) AS region_key
    FROM raw.mof_control_call mcc
    LEFT JOIN master.dim_mof_port_code pr ON pr.prt_ag_cd = mcc.prt_ag_cd
),
by_co AS (
    /* 신고처 항구 + 신고 입항횟수 일치 → 시각 차이로 등급 1 / 5 */
    SELECT s.raw_id AS ship_call_raw_id, c.control_call_raw_id,
           ABS(EXTRACT(EPOCH FROM (c.aprtf_etrypt_dt - s.arrival_dt))) AS gap_sec,
           c.aprtf_etrypt_dt, s.reported_departure_dt
    FROM ship s
    JOIN ctrl c
      ON s.prt_ag_cd        = COALESCE(c.vssl_satmnt_ag_cd, c.prt_ag_cd)
     AND c.clsgn            = s.clsgn
     AND c.etrypt_year      = s.etrypt_yr
     AND c.satmnt_etrypt_co = s.etrypt_co
    WHERE c.satmnt_etrypt_co IS NOT NULL
)
SELECT ship_call_raw_id, control_call_raw_id, 1 AS grade, gap_sec
FROM by_co
WHERE gap_sec IS NULL OR gap_sec <= 6 * 3600
UNION ALL
SELECT ship_call_raw_id, control_call_raw_id, 5, gap_sec
FROM by_co
WHERE gap_sec > 6 * 3600
  AND NOT (reported_departure_dt IS NOT NULL AND aprtf_etrypt_dt > reported_departure_dt)
UNION ALL
/* 입항시각 완전 일치 (같은 권역) → 등급 2 / 3 / 4 */
SELECT s.raw_id, c.control_call_raw_id,
       CASE WHEN c.satmnt_etrypt_co IS NOT NULL THEN 4
            WHEN c.prt_ag_cd = s.prt_ag_cd       THEN 2
            ELSE 3 END,
       0
FROM ship s
JOIN ctrl c
  ON c.clsgn           = s.clsgn
 AND c.etrypt_year     = s.etrypt_yr
 AND c.aprtf_etrypt_dt = s.arrival_dt
 AND c.region_key      = s.region_key;

ANALYZE tmp_match_cand;

/* 3-2. 등급 순서대로 1:1 배정
        신고별로 가장 가까운 관제 → 관제별로 가장 가까운 신고 */
DROP TABLE IF EXISTS tmp_control_match;
CREATE TEMP TABLE tmp_control_match (
    ship_call_raw_id    bigint PRIMARY KEY,
    control_call_raw_id bigint UNIQUE,
    match_priority      smallint
);

DO $$
DECLARE g int;
BEGIN
    FOR g IN 1..5 LOOP
        INSERT INTO tmp_control_match (ship_call_raw_id, control_call_raw_id, match_priority)
        SELECT ship_call_raw_id, control_call_raw_id, g
        FROM (
            SELECT DISTINCT ON (control_call_raw_id) ship_call_raw_id, control_call_raw_id
            FROM (
                SELECT DISTINCT ON (mc.ship_call_raw_id) mc.ship_call_raw_id, mc.control_call_raw_id, mc.gap_sec
                FROM tmp_match_cand mc
                WHERE mc.grade = g
                  AND NOT EXISTS (SELECT 1 FROM tmp_control_match m WHERE m.ship_call_raw_id    = mc.ship_call_raw_id)
                  AND NOT EXISTS (SELECT 1 FROM tmp_control_match m WHERE m.control_call_raw_id = mc.control_call_raw_id)
                ORDER BY mc.ship_call_raw_id, mc.gap_sec NULLS LAST, mc.control_call_raw_id DESC
            ) per_ship
            ORDER BY control_call_raw_id, gap_sec NULLS LAST, ship_call_raw_id
        ) per_control;
    END LOOP;
END $$;

/* 3-3. 등급 6: 근사 매칭 (같은 권역 + 입항시각 ±60분) */
INSERT INTO tmp_control_match (ship_call_raw_id, control_call_raw_id, match_priority)
SELECT ship_call_raw_id, control_call_raw_id, 6
FROM (
    SELECT DISTINCT ON (control_call_raw_id)
        ship_call_raw_id, control_call_raw_id
    FROM (
        SELECT DISTINCT ON (msc.raw_id)
            msc.raw_id AS ship_call_raw_id,
            mcc.control_call_raw_id,
            ABS(EXTRACT(EPOCH FROM (mcc.aprtf_etrypt_dt - msc.arrival_dt))) AS gap_sec
        FROM raw.mof_ship_call msc
        JOIN raw.mof_control_call mcc
          ON mcc.clsgn = msc.clsgn
         AND mcc.aprtf_etrypt_dt BETWEEN msc.arrival_dt - INTERVAL '60 minutes'
                                     AND msc.arrival_dt + INTERVAL '60 minutes'
        LEFT JOIN master.dim_mof_port_code rs ON rs.prt_ag_cd = msc.prt_ag_cd
        LEFT JOIN master.dim_mof_port_code rc ON rc.prt_ag_cd = mcc.prt_ag_cd
        WHERE COALESCE(rc.region_key, mcc.prt_ag_cd) = COALESCE(rs.region_key, msc.prt_ag_cd)
          AND NOT EXISTS (SELECT 1 FROM tmp_control_match m WHERE m.ship_call_raw_id    = msc.raw_id)
          AND NOT EXISTS (SELECT 1 FROM tmp_control_match m WHERE m.control_call_raw_id = mcc.control_call_raw_id)
        ORDER BY msc.raw_id, gap_sec, mcc.control_call_raw_id DESC
    ) per_ship
    ORDER BY control_call_raw_id, gap_sec, ship_call_raw_id
) per_control;


/* 실제 행 수로 통계 갱신 → 아래 INSERT에서 Hash Join 선택 */
ANALYZE tmp_control_match;


/* =====================================================================
   3-4. 중복 신고 의심 그룹
        같은 호출부호 + 입항시각 60분 이내 + 머문 기간이 겹치는 신고
        (항구 무관: 같은 배가 동시에 두 곳에 머물 수 없음)
        - 앞선 신고의 출항이 뒤 신고의 입항보다 이전이면 연속 입항 → 중복 아님
          (예: 12:20 입항 → 12:47 출항 → 13:20 재입항)
        - 출항 정보가 없으면 겹치는 것으로 봄
        - 출항 = 신고 출항, 없으면 매칭된 관제의 출항
        신고마다 그룹 안의 대표를 고름: 관제 매칭 등급 높은 순 → raw_id 큰 순
   ===================================================================== */
DROP TABLE IF EXISTS tmp_dup;
CREATE TEMP TABLE tmp_dup AS
WITH s AS (
    SELECT msc.raw_id, msc.clsgn, msc.arrival_dt,
           (msc.arrival_dt AT TIME ZONE 'Asia/Seoul')                 AS arr_ts,
           COALESCE(sd.reported_departure_dt, cs.actual_departure_dt) AS dep_ts,
           m.match_priority
    FROM raw.mof_ship_call msc
    LEFT JOIN tmp_ship_detail sd     ON sd.ship_call_raw_id    = msc.raw_id
    LEFT JOIN tmp_control_match m    ON m.ship_call_raw_id     = msc.raw_id
    LEFT JOIN tmp_control_summary cs ON cs.control_call_raw_id = m.control_call_raw_id
    WHERE msc.arrival_dt IS NOT NULL
      AND msc.clsgn IS NOT NULL
)
SELECT ship_call_raw_id, best_raw_id
FROM (
    SELECT DISTINCT ON (a.raw_id)
        a.raw_id AS ship_call_raw_id,
        b.raw_id AS best_raw_id,
        COUNT(*) OVER (PARTITION BY a.raw_id) AS cluster_size
    FROM s a
    JOIN s b
      ON b.clsgn = a.clsgn
     AND b.arrival_dt BETWEEN a.arrival_dt - INTERVAL '60 minutes'
                          AND a.arrival_dt + INTERVAL '60 minutes'
     AND (
             b.raw_id = a.raw_id
          OR NOT (   (a.arr_ts <= b.arr_ts AND COALESCE(a.dep_ts < b.arr_ts, false))   -- a 출항 후 b 입항
                  OR (b.arr_ts <= a.arr_ts AND COALESCE(b.dep_ts < a.arr_ts, false)))  -- b 출항 후 a 입항
                                                                                       -- 출항 모르면 겹침으로 봄
         )
    ORDER BY a.raw_id, b.match_priority NULLS LAST, b.raw_id DESC
) x
WHERE cluster_size > 1;

ANALYZE tmp_dup;
ANALYZE tmp_control_summary;
ANALYZE tmp_ship_detail;


/* =====================================================================
   4. Fact 적재
   ===================================================================== */
INSERT INTO fact.fact_ship_call AS f (
    ship_call_raw_id,
    control_call_raw_id,
    port_code,
    port_name,
    etrypt_year,
    etrypt_co,
    clsgn,
    vessel_name,
    aprtf_etrypt_dt,
    reported_arrival_dt,
    arrival_request_type,
    reported_departure_dt,
    departure_request_type,
    actual_arrival_dt,
    actual_departure_dt,
    arrival_dt,
    arrival_source,
    departure_dt,
    departure_source,
    last_control_event,
    last_control_event_dt,
    last_facility_code,
    last_facility_sub_code,
    last_facility_name,
    ibobprt_nm,
    stay_minutes,
    control_expected,
    control_match_priority,
    suspected_duplicate,
    duplicate_of_ship_call_raw_id,
    gross_tonnage,
    vessel_kind_cd
)
WITH fact_base AS (
    SELECT
        msc.raw_id          AS ship_call_raw_id,
        cm.control_call_raw_id,
        cm.match_priority   AS control_match_priority,
        (dp.ship_call_raw_id IS NOT NULL)                         AS suspected_duplicate,
        /* 총톤수: 신고 → 없으면 관제 */
        COALESCE(sd.reported_gross_tonnage, NULLIF(mcc.vssl_grtg, 0)) AS gross_tonnage,
        msc.vssl_knd_cd                                           AS vessel_kind_cd,
        CASE WHEN dp.best_raw_id <> msc.raw_id THEN dp.best_raw_id END AS duplicate_of_ship_call_raw_id,
        msc.prt_ag_cd       AS port_code,
        msc.prt_ag_nm       AS port_name,
        msc.etrypt_yr       AS etrypt_year,
        msc.etrypt_co       AS etrypt_co,
        msc.clsgn           AS clsgn,
        msc.vssl_nm         AS vessel_name,

        /* control parent의 기항지 입항일시 */
        mcc.aprtf_etrypt_dt,

        /* ship call 신고 정보 */
        sd.reported_arrival_dt,
        sd.arrival_request_type,
        sd.reported_departure_dt,
        sd.departure_request_type,

        /* control 실제 관제 정보 */
        cs.actual_arrival_dt,
        cs.actual_departure_dt,

        /* 대표 입출항 시각 (v9: 확정 신고 우선) → 아래 LATERAL a, d 참고 */
        a.arrival_dt,
        a.arrival_source,
        d.departure_dt,
        d.departure_source,

        /* 마지막 관제 상태 */
        cs.last_control_event,
        cs.last_control_event_dt,
        cs.last_facility_code,
        cs.last_facility_sub_code,
        cs.last_facility_name,

        sd.ibobprt_nm,

        /* 관제 대상 여부: 비대상 선종이거나, 내항 비대상 선종이 내항 입항이면 false
           코드표에 없는 선종은 대상(true)으로 봄 */
        COALESCE(vk.control_expected, true)
        AND NOT (COALESCE(vk.control_exempt_domestic, false)
                 AND COALESCE(sd.ibobprt_nm = '내항', false))   AS control_expected
    FROM raw.mof_ship_call msc
    LEFT JOIN tmp_ship_detail sd
           ON sd.ship_call_raw_id = msc.raw_id
    LEFT JOIN tmp_control_match cm
           ON cm.ship_call_raw_id = msc.raw_id
    LEFT JOIN raw.mof_control_call mcc
           ON mcc.control_call_raw_id = cm.control_call_raw_id
    LEFT JOIN tmp_control_summary cs
           ON cs.control_call_raw_id = cm.control_call_raw_id
    LEFT JOIN master.dim_mof_vessel_kind vk
           ON vk.vssl_knd_cd = msc.vssl_knd_cd
    LEFT JOIN tmp_dup dp
           ON dp.ship_call_raw_id = msc.raw_id

    /* 대표 입항시각
       1. 신고 입항이 '최종'이면 신고          → SHIP_CALL
       2. 아니면 관제 실제 입항                → CONTROL
       3. 관제가 없으면 확정 전 신고(최초·변경) → SHIP_CALL */
    CROSS JOIN LATERAL (
        SELECT
            CASE
                WHEN sd.arrival_request_type = '최종' AND sd.reported_arrival_dt IS NOT NULL THEN sd.reported_arrival_dt
                WHEN cs.actual_arrival_dt   IS NOT NULL THEN cs.actual_arrival_dt
                WHEN sd.reported_arrival_dt IS NOT NULL THEN sd.reported_arrival_dt
            END AS arrival_dt,
            CASE
                WHEN sd.arrival_request_type = '최종' AND sd.reported_arrival_dt IS NOT NULL THEN 'SHIP_CALL'
                WHEN cs.actual_arrival_dt   IS NOT NULL THEN 'CONTROL'
                WHEN sd.reported_arrival_dt IS NOT NULL THEN 'SHIP_CALL'
            END AS arrival_source
    ) a

    /* 대표 출항시각 (대표 입항 이후인 값만)
       1. 신고 출항이 '최종'이면 신고          → SHIP_CALL
       2. 아니면 관제 실제 출항                → CONTROL
       3. 관제가 없으면 확정 전 신고(최초·변경) → SHIP_CALL */
    CROSS JOIN LATERAL (
        SELECT
            CASE
                WHEN sd.departure_request_type = '최종' AND sd.reported_departure_dt >= a.arrival_dt THEN sd.reported_departure_dt
                WHEN cs.actual_departure_dt   >= a.arrival_dt THEN cs.actual_departure_dt
                WHEN sd.reported_departure_dt >= a.arrival_dt THEN sd.reported_departure_dt
            END AS departure_dt,
            CASE
                WHEN sd.departure_request_type = '최종' AND sd.reported_departure_dt >= a.arrival_dt THEN 'SHIP_CALL'
                WHEN cs.actual_departure_dt   >= a.arrival_dt THEN 'CONTROL'
                WHEN sd.reported_departure_dt >= a.arrival_dt THEN 'SHIP_CALL'
            END AS departure_source
    ) d
)
SELECT
    ship_call_raw_id,
    control_call_raw_id,
    port_code,
    port_name,
    etrypt_year,
    etrypt_co,
    clsgn,
    vessel_name,
    aprtf_etrypt_dt,
    reported_arrival_dt,
    arrival_request_type,
    reported_departure_dt,
    departure_request_type,
    actual_arrival_dt,
    actual_departure_dt,
    arrival_dt,
    arrival_source,
    departure_dt,
    departure_source,
    last_control_event,
    last_control_event_dt,
    last_facility_code,
    last_facility_sub_code,
    last_facility_name,
    ibobprt_nm,
    /* 체류시간(분) */
    CASE
        WHEN arrival_dt IS NOT NULL
         AND departure_dt IS NOT NULL
         AND departure_dt >= arrival_dt
        THEN (EXTRACT(EPOCH FROM (departure_dt - arrival_dt)) / 60)::BIGINT
    END AS stay_minutes,
    control_expected,
    control_match_priority,
    suspected_duplicate,
    duplicate_of_ship_call_raw_id,
    gross_tonnage,
    vessel_kind_cd
FROM fact_base
ON CONFLICT (ship_call_raw_id)
DO UPDATE SET
    port_code              = EXCLUDED.port_code,
    etrypt_year            = EXCLUDED.etrypt_year,
    etrypt_co              = EXCLUDED.etrypt_co,
    clsgn                  = EXCLUDED.clsgn,
    aprtf_etrypt_dt        = EXCLUDED.aprtf_etrypt_dt,
    control_call_raw_id    = EXCLUDED.control_call_raw_id,
    port_name              = EXCLUDED.port_name,
    vessel_name            = EXCLUDED.vessel_name,
    reported_arrival_dt    = EXCLUDED.reported_arrival_dt,
    arrival_request_type   = EXCLUDED.arrival_request_type,
    reported_departure_dt  = EXCLUDED.reported_departure_dt,
    departure_request_type = EXCLUDED.departure_request_type,
    actual_arrival_dt      = EXCLUDED.actual_arrival_dt,
    actual_departure_dt    = EXCLUDED.actual_departure_dt,
    arrival_dt             = EXCLUDED.arrival_dt,
    arrival_source         = EXCLUDED.arrival_source,
    departure_dt           = EXCLUDED.departure_dt,
    departure_source       = EXCLUDED.departure_source,
    last_control_event     = EXCLUDED.last_control_event,
    last_control_event_dt  = EXCLUDED.last_control_event_dt,
    last_facility_code     = EXCLUDED.last_facility_code,
    last_facility_sub_code = EXCLUDED.last_facility_sub_code,
    last_facility_name     = EXCLUDED.last_facility_name,
    ibobprt_nm             = EXCLUDED.ibobprt_nm,
    stay_minutes           = EXCLUDED.stay_minutes,
    control_expected       = EXCLUDED.control_expected,
    control_match_priority = EXCLUDED.control_match_priority,
    suspected_duplicate    = EXCLUDED.suspected_duplicate,
    duplicate_of_ship_call_raw_id = EXCLUDED.duplicate_of_ship_call_raw_id,
    gross_tonnage          = EXCLUDED.gross_tonnage,
    vessel_kind_cd         = EXCLUDED.vessel_kind_cd,
    updated_at             = CURRENT_TIMESTAMP
/* 값이 실제로 바뀐 행만 UPDATE */
WHERE (
    f.port_code, f.etrypt_year, f.etrypt_co, f.clsgn, f.aprtf_etrypt_dt,
    f.control_call_raw_id, f.port_name, f.vessel_name,
    f.reported_arrival_dt, f.arrival_request_type,
    f.reported_departure_dt, f.departure_request_type,
    f.actual_arrival_dt, f.actual_departure_dt,
    f.arrival_dt, f.arrival_source,
    f.departure_dt, f.departure_source,
    f.last_control_event, f.last_control_event_dt,
    f.last_facility_code, f.last_facility_sub_code, f.last_facility_name,
    f.ibobprt_nm, f.stay_minutes, f.control_expected, f.control_match_priority,
    f.suspected_duplicate, f.duplicate_of_ship_call_raw_id,
    f.gross_tonnage, f.vessel_kind_cd
) IS DISTINCT FROM (
    EXCLUDED.port_code, EXCLUDED.etrypt_year, EXCLUDED.etrypt_co, EXCLUDED.clsgn, EXCLUDED.aprtf_etrypt_dt,
    EXCLUDED.control_call_raw_id, EXCLUDED.port_name, EXCLUDED.vessel_name,
    EXCLUDED.reported_arrival_dt, EXCLUDED.arrival_request_type,
    EXCLUDED.reported_departure_dt, EXCLUDED.departure_request_type,
    EXCLUDED.actual_arrival_dt, EXCLUDED.actual_departure_dt,
    EXCLUDED.arrival_dt, EXCLUDED.arrival_source,
    EXCLUDED.departure_dt, EXCLUDED.departure_source,
    EXCLUDED.last_control_event, EXCLUDED.last_control_event_dt,
    EXCLUDED.last_facility_code, EXCLUDED.last_facility_sub_code, EXCLUDED.last_facility_name,
    EXCLUDED.ibobprt_nm, EXCLUDED.stay_minutes, EXCLUDED.control_expected, EXCLUDED.control_match_priority,
    EXCLUDED.suspected_duplicate, EXCLUDED.duplicate_of_ship_call_raw_id,
    EXCLUDED.gross_tonnage, EXCLUDED.vessel_kind_cd
);

COMMIT;
