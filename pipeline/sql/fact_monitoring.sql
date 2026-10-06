/* =====================================================================
   fact.fact_ship_call 모니터링 쿼리 (읽기 전용)
   적재 후 필요한 쿼리만 골라 실행
   시각 비교가 있는 쿼리(3, 9번)는 세션 시간대가 Asia/Seoul이어야 정확함
   ===================================================================== */

SET TIME ZONE 'Asia/Seoul';


/* ---------------------------------------------------------------------
   1. 적재 상태 요약
      total = distinct_ship_calls 이어야 함 (중복 없음)
   --------------------------------------------------------------------- */
SELECT COUNT(*)                                                    AS total,
       COUNT(DISTINCT ship_call_raw_id)                            AS distinct_ship_calls,
       COUNT(*) FILTER (WHERE control_call_raw_id IS NULL)         AS unmatched_all,
       COUNT(*) FILTER (WHERE control_expected
                          AND control_call_raw_id IS NULL
                          AND duplicate_of_ship_call_raw_id IS NULL) AS unmatched_expected,
       COUNT(*) FILTER (WHERE duplicate_of_ship_call_raw_id IS NOT NULL) AS duplicate_rows,
       ROUND(100.0 * COUNT(*) FILTER (WHERE control_expected AND control_call_raw_id IS NOT NULL
                                           AND duplicate_of_ship_call_raw_id IS NULL)
                   / NULLIF(COUNT(*) FILTER (WHERE control_expected
                                               AND duplicate_of_ship_call_raw_id IS NULL), 0), 1) AS match_rate_expected_pct,
       COUNT(*) FILTER (WHERE control_expected IS NULL)            AS control_expected_null,
       MAX(updated_at)                                             AS last_updated
FROM fact.fact_ship_call;


/* ---------------------------------------------------------------------
   2. 관제 대상 / 비대상별 미매칭
   --------------------------------------------------------------------- */
SELECT CASE WHEN control_expected THEN '관제 대상' ELSE '관제 비대상' END AS grp,
       COUNT(*)                                            AS total,
       COUNT(*) FILTER (WHERE control_call_raw_id IS NULL) AS unmatched
FROM fact.fact_ship_call
GROUP BY 1
ORDER BY 1;


/* ---------------------------------------------------------------------
   3. 점검 대상 목록: 관제 대상인데 미매칭 (중복 신고로 표시된 건 제외)
      가까운 관제(같은 호출부호, 입항시각 기준)와 시각 차이를 함께 표시
      시각차가 0에 가까우면 매칭 규칙이 놓친 건, 6시간 넘으면 다른 입항
   --------------------------------------------------------------------- */
SELECT f.ship_call_raw_id,
       f.port_code, f.port_name, f.clsgn, f.vessel_name,
       f.etrypt_year, f.etrypt_co,
       msc.arrival_dt,
       msc.vssl_knd_nm,
       f.ibobprt_nm,
       nc.prt_ag_cd                                   AS near_ctrl_port,
       nc.satmnt_etrypt_co                            AS near_ctrl_satmnt_co,
       nc.aprtf_etrypt_dt                             AS near_ctrl_arrival,
       ROUND(EXTRACT(EPOCH FROM (nc.aprtf_etrypt_dt::timestamptz - msc.arrival_dt)) / 3600, 1) AS gap_hours
FROM fact.fact_ship_call f
JOIN raw.mof_ship_call msc ON msc.raw_id = f.ship_call_raw_id
LEFT JOIN LATERAL (
    SELECT c.prt_ag_cd, c.satmnt_etrypt_co, c.aprtf_etrypt_dt
    FROM raw.mof_control_call c
    WHERE c.clsgn = msc.clsgn
    ORDER BY ABS(EXTRACT(EPOCH FROM (c.aprtf_etrypt_dt::timestamptz - msc.arrival_dt))) NULLS LAST
    LIMIT 1
) nc ON true
WHERE f.control_expected
  AND f.control_call_raw_id IS NULL
  AND f.duplicate_of_ship_call_raw_id IS NULL
ORDER BY ABS(EXTRACT(EPOCH FROM (nc.aprtf_etrypt_dt::timestamptz - msc.arrival_dt))) NULLS LAST;


/* ---------------------------------------------------------------------
   4. 관제 대상 미매칭: 선종별
   --------------------------------------------------------------------- */
SELECT msc.vssl_knd_cd, msc.vssl_knd_nm,
       COUNT(*)                                              AS total,
       COUNT(*) FILTER (WHERE f.control_call_raw_id IS NULL) AS unmatched,
       ROUND(100.0 * COUNT(*) FILTER (WHERE f.control_call_raw_id IS NULL) / COUNT(*), 1) AS unmatched_pct
FROM fact.fact_ship_call f
JOIN raw.mof_ship_call msc ON msc.raw_id = f.ship_call_raw_id
WHERE f.control_expected
GROUP BY 1, 2
HAVING COUNT(*) FILTER (WHERE f.control_call_raw_id IS NULL) > 0
ORDER BY unmatched DESC;


/* ---------------------------------------------------------------------
   5. 규칙 점검: 비대상으로 표시했는데 실제로는 매칭된 건
      0이 아니면 그 선종은 관제를 받는 경우가 있다는 뜻
      (2026-10-05 기준: 포항신항 내항 여객선 1건)
   --------------------------------------------------------------------- */
SELECT msc.vssl_knd_cd, msc.vssl_knd_nm, f.port_name, f.ibobprt_nm,
       COUNT(*) AS matched_but_exempt
FROM fact.fact_ship_call f
JOIN raw.mof_ship_call msc ON msc.raw_id = f.ship_call_raw_id
WHERE NOT f.control_expected
  AND f.control_call_raw_id IS NOT NULL
GROUP BY 1, 2, 3, 4
ORDER BY matched_but_exempt DESC;


/* ---------------------------------------------------------------------
   6. 코드표 점검: raw에는 있는데 코드표에 없는 값 (0건이어야 함)
      새로 나온 코드는 기본값 '관제 대상'으로 처리되므로 코드표에 추가 후 판단
   --------------------------------------------------------------------- */
SELECT '선박 종류' AS code_type, msc.vssl_knd_cd AS code, MAX(msc.vssl_knd_nm) AS name, COUNT(*) AS ship_calls
FROM raw.mof_ship_call msc
LEFT JOIN master.dim_mof_vessel_kind vk ON vk.vssl_knd_cd = msc.vssl_knd_cd
WHERE msc.vssl_knd_cd IS NOT NULL AND vk.vssl_knd_cd IS NULL
GROUP BY msc.vssl_knd_cd
UNION ALL
SELECT '항구', x.prt_ag_cd, MAX(x.prt_ag_nm), COUNT(*)
FROM (
    SELECT prt_ag_cd, prt_ag_nm FROM raw.mof_ship_call
    UNION ALL
    SELECT prt_ag_cd, prt_ag_nm FROM raw.mof_control_call
) x
LEFT JOIN master.dim_mof_port_code p ON p.prt_ag_cd = x.prt_ag_cd
WHERE x.prt_ag_cd IS NOT NULL AND p.prt_ag_cd IS NULL
GROUP BY x.prt_ag_cd;


/* ---------------------------------------------------------------------
   7. 매칭 등급별 건수 (적재 직후 같은 세션에서만, 임시 테이블 사용)
   --------------------------------------------------------------------- */
-- SELECT match_priority, COUNT(*) FROM tmp_control_match GROUP BY 1 ORDER BY 1;


/* ---------------------------------------------------------------------
   8. 매칭 등급 분포 (fact.control_match_priority, v7 기준)
      1 입항횟수 일치+6시간 이내   2 같은 항구+시각 일치   3 같은 권역+시각 일치
      4 입항횟수 어긋남+시각 일치  5 입항횟수 일치+6시간 초과   6 ±60분 근사
   --------------------------------------------------------------------- */
SELECT COALESCE(control_match_priority::text, '미매칭') AS priority,
       COUNT(*) AS cnt
FROM fact.fact_ship_call
GROUP BY control_match_priority
ORDER BY control_match_priority NULLS LAST;


/* ---------------------------------------------------------------------
   9. 4·5·6등급 매칭 목록 (눈으로 확인용)
      5는 시각 차이가 큰 입항횟수 매칭, 6은 ±60분 근사 매칭
   --------------------------------------------------------------------- */
SELECT f.control_match_priority,
       f.port_code, f.port_name, f.clsgn, f.vessel_name, f.etrypt_co,
       c.prt_ag_cd          AS ctrl_port,
       c.satmnt_etrypt_co   AS ctrl_satmnt_co,
       msc.arrival_dt,
       c.aprtf_etrypt_dt    AS ctrl_arrival,
       ROUND(EXTRACT(EPOCH FROM (c.aprtf_etrypt_dt::timestamptz - msc.arrival_dt)) / 60) AS gap_min
FROM fact.fact_ship_call f
JOIN raw.mof_ship_call msc   ON msc.raw_id = f.ship_call_raw_id
JOIN raw.mof_control_call c  ON c.control_call_raw_id = f.control_call_raw_id
WHERE f.control_match_priority IN (4, 5, 6)
ORDER BY f.control_match_priority, ABS(EXTRACT(EPOCH FROM (c.aprtf_etrypt_dt::timestamptz - msc.arrival_dt)));


/* ---------------------------------------------------------------------
   10. 관제 1:1 점검: 신고 여러 건에 배정된 관제 (v7부터 0이어야 함)
   --------------------------------------------------------------------- */
SELECT control_call_raw_id, COUNT(*) AS ship_calls
FROM fact.fact_ship_call
WHERE control_call_raw_id IS NOT NULL
GROUP BY 1
HAVING COUNT(*) > 1;


/* ---------------------------------------------------------------------
   11. 중복 신고 의심 목록 (같은 배, 입항시각 60분 이내, 머문 기간 겹침)
       is_representative = true 인 행이 그룹의 대표
   --------------------------------------------------------------------- */
SELECT COALESCE(f.duplicate_of_ship_call_raw_id, f.ship_call_raw_id) AS group_rep_raw_id,
       (f.duplicate_of_ship_call_raw_id IS NULL)                      AS is_representative,
       f.ship_call_raw_id, f.port_code, f.port_name, f.clsgn, f.vessel_name,
       f.etrypt_co, msc.arrival_dt, f.departure_dt,
       f.control_call_raw_id, f.control_match_priority
FROM fact.fact_ship_call f
JOIN raw.mof_ship_call msc ON msc.raw_id = f.ship_call_raw_id
WHERE f.suspected_duplicate
ORDER BY f.clsgn, msc.arrival_dt, is_representative DESC, f.ship_call_raw_id;


/* =====================================================================
   관제 이벤트 (fact.fact_control_event / master.dim_control_event_type)
   ===================================================================== */

/* ---------------------------------------------------------------------
   12. 이벤트 코드 분류 점검: '기타'이거나 자동 추가된 코드 (분류 후 직접 수정)
       UPDATE master.dim_control_event_type
          SET event_group = '…', location_after = '…', note = NULL, updated_at = CURRENT_TIMESTAMP
        WHERE event_code = '…';
   --------------------------------------------------------------------- */
SELECT t.event_code, t.event_name, t.event_group, t.location_after, t.note,
       COUNT(e.control_event_id) AS events
FROM master.dim_control_event_type t
LEFT JOIN fact.fact_control_event e ON e.event_code = t.event_code
GROUP BY 1, 2, 3, 4, 5
ORDER BY (t.event_group = '기타') DESC, events DESC;


/* ---------------------------------------------------------------------
   13. 관제 이벤트 적재 점검
       raw_events = fact_events, 시간 역전(minutes_to_next < 0)은 원천 순번/시각 불일치
   --------------------------------------------------------------------- */
SELECT (SELECT COUNT(*) FROM raw.mof_control_event)                          AS raw_events,
       COUNT(*)                                                              AS fact_events,
       COUNT(DISTINCT control_call_raw_id)                                   AS control_calls,
       COUNT(*) FILTER (WHERE minutes_to_next < 0)                           AS negative_interval,
       COUNT(*) FILTER (WHERE is_last_event AND event_name NOT LIKE '%출항%') AS calls_in_progress,
       MAX(updated_at)                                                       AS last_updated
FROM fact.fact_control_event;


/* ---------------------------------------------------------------------
   14. 대표 입출항 시각 출처 분포 (v9: 최종 신고 → 관제 실측 → 확정 전 신고)
   --------------------------------------------------------------------- */
SELECT arrival_source, departure_source,
       arrival_request_type, departure_request_type,
       COUNT(*) AS cnt
FROM fact.fact_ship_call
GROUP BY 1, 2, 3, 4
ORDER BY cnt DESC;


/* ---------------------------------------------------------------------
   15. (mart 시제품) 항만별 평균 정박지 대기 시간 / 접안 시간
       다음 이벤트까지의 시간을 그 사이 배가 있던 곳으로 나눠 합산
       위치: dim의 location_after, 입항처럼 NULL이면 시설명으로 판단(정박지/묘박지 → 정박지, 그 외 선석)
   --------------------------------------------------------------------- */
WITH ev AS (
    SELECT e.control_call_raw_id, e.minutes_to_next,
           COALESCE(t.location_after,
                    CASE WHEN e.facility_name LIKE '%정박지%' OR e.facility_name LIKE '%묘박%'
                         THEN '정박지' ELSE '선석' END) AS location
    FROM fact.fact_control_event e
    LEFT JOIN master.dim_control_event_type t ON t.event_code = e.event_code
    WHERE e.minutes_to_next IS NOT NULL
),
per_call AS (
    SELECT control_call_raw_id,
           SUM(minutes_to_next) FILTER (WHERE location = '정박지') AS anchorage_min,
           SUM(minutes_to_next) FILTER (WHERE location = '선석')   AS berth_min
    FROM ev
    GROUP BY 1
)
SELECT f.port_code, f.port_name,
       COUNT(*)                                   AS calls,
       ROUND(AVG(p.anchorage_min) / 60.0, 1)      AS avg_anchorage_hours,
       ROUND(AVG(p.berth_min)     / 60.0, 1)      AS avg_berth_hours
FROM fact.fact_ship_call f
JOIN per_call p ON p.control_call_raw_id = f.control_call_raw_id
WHERE f.duplicate_of_ship_call_raw_id IS NULL
GROUP BY 1, 2
ORDER BY calls DESC;


/* =====================================================================
   mart.port_daily_kpi
   ===================================================================== */

/* ---------------------------------------------------------------------
   16. mart 적재 점검: fact와 합계 일치 (mart_arrivals = fact_arrivals)
   --------------------------------------------------------------------- */
SELECT (SELECT SUM(arrivals) FROM mart.port_daily_kpi)                         AS mart_arrivals,
       (SELECT COUNT(*) FROM fact.fact_ship_call
         WHERE duplicate_of_ship_call_raw_id IS NULL
           AND arrival_dt::date BETWEEN (SELECT MIN(kpi_date) FROM mart.port_daily_kpi) AND CURRENT_DATE) AS fact_arrivals,
       (SELECT COUNT(DISTINCT port_code) FROM mart.port_daily_kpi)             AS ports,
       (SELECT MIN(kpi_date) FROM mart.port_daily_kpi)                         AS first_date,
       (SELECT MAX(kpi_date) FROM mart.port_daily_kpi)                         AS last_date,
       (SELECT MAX(refreshed_at) FROM mart.port_daily_kpi)                     AS refreshed_at;


/* ---------------------------------------------------------------------
   17. 최근 14일 이상징후
   --------------------------------------------------------------------- */
SELECT kpi_date, port_code, port_name,
       arrivals, arrivals_mean_28d, arrivals_zscore,
       departures, departures_mean_28d, departures_zscore,
       anomaly_reason
FROM mart.port_daily_kpi
WHERE is_anomaly
  AND kpi_date >= CURRENT_DATE - 14
ORDER BY kpi_date DESC, GREATEST(ABS(COALESCE(arrivals_zscore, 0)), ABS(COALESCE(departures_zscore, 0))) DESC;


/* ---------------------------------------------------------------------
   18. mart '수집된 날' 판정 확인
       전국 입항이 일별 중앙값의 20% 미만이라 mart에서 빠진 날
       (미수집 기간에 섞여 들어온 소량 레코드, 수집 경계일 등)
       → 실제로 수집한 날이 여기 나오면 min_collected_ratio를 낮출 것
   --------------------------------------------------------------------- */
WITH d AS (
    SELECT arrival_dt::date AS kpi_date, COUNT(*) AS total_arrivals
    FROM fact.fact_ship_call
    WHERE arrival_dt IS NOT NULL AND arrival_dt::date <= CURRENT_DATE
    GROUP BY 1
), med AS (
    SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY total_arrivals) AS median_daily FROM d
)
SELECT d.kpi_date, d.total_arrivals, ROUND(m.median_daily::numeric, 0) AS median_daily,
       ROUND(100.0 * d.total_arrivals / m.median_daily::numeric, 1) AS pct_of_median
FROM d CROSS JOIN med m
WHERE d.kpi_date NOT IN (SELECT DISTINCT kpi_date FROM mart.port_daily_kpi)
ORDER BY d.kpi_date;
