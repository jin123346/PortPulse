/* =====================================================================
   적재 후 모니터링 요약 (읽기 전용, 결과 1행)
   transform_service 마지막에 실행해 report JSON의 transform_result.monitoring 으로 저장
   - 모니터링 1번 (매칭률), 13번 (관제 이벤트 건수), 16번 (mart 합계), 18번 (mart에서 빠진 날)을 한 줄로
   ===================================================================== */
WITH fsc AS (
    SELECT
        COUNT(*)                                                              AS ship_calls,
        COUNT(*) FILTER (WHERE duplicate_of_ship_call_raw_id IS NOT NULL)     AS duplicate_rows,
        COUNT(*) FILTER (WHERE control_expected
                           AND control_call_raw_id IS NULL
                           AND duplicate_of_ship_call_raw_id IS NULL)         AS unmatched_expected,
        ROUND(100.0 * COUNT(*) FILTER (WHERE control_expected AND control_call_raw_id IS NOT NULL
                                            AND duplicate_of_ship_call_raw_id IS NULL)
              / NULLIF(COUNT(*) FILTER (WHERE control_expected
                                          AND duplicate_of_ship_call_raw_id IS NULL), 0), 1) AS match_pct
    FROM fact.fact_ship_call
),
evt AS (
    SELECT (SELECT COUNT(*) FROM raw.mof_control_event)  AS raw_events,
           (SELECT COUNT(*) FROM fact.fact_control_event) AS fact_events
),
mart AS (
    SELECT MIN(kpi_date) AS first_date, MAX(kpi_date) AS last_date,
           COUNT(DISTINCT kpi_date) AS mart_days,
           SUM(arrivals) AS mart_arrivals,
           COUNT(*) FILTER (WHERE is_anomaly AND kpi_date >= CURRENT_DATE - 14) AS anomalies_14d
    FROM mart.port_daily_kpi
),
fact_in_mart AS (
    /* mart에 들어간 날짜 기준 fact 입항 수 (중복 제외) → mart_arrivals와 같아야 함 */
    SELECT COUNT(*) AS fact_arrivals
    FROM fact.fact_ship_call f
    WHERE f.duplicate_of_ship_call_raw_id IS NULL
      AND f.port_code IS NOT NULL
      AND f.arrival_dt::date IN (SELECT DISTINCT kpi_date FROM mart.port_daily_kpi)
),
missing AS (
    /* fact에는 입항이 있는데 mart에서 빠진 날 (수집 경계일 등) */
    SELECT COUNT(*) AS missing_days
    FROM (SELECT DISTINCT arrival_dt::date AS d
          FROM fact.fact_ship_call
          WHERE arrival_dt IS NOT NULL AND arrival_dt::date <= CURRENT_DATE
            AND duplicate_of_ship_call_raw_id IS NULL) x
    WHERE x.d NOT IN (SELECT DISTINCT kpi_date FROM mart.port_daily_kpi)
)
SELECT fsc.ship_calls, fsc.duplicate_rows, fsc.unmatched_expected, fsc.match_pct,
       evt.raw_events, evt.fact_events,
       mart.first_date, mart.last_date, mart.mart_days,
       mart.mart_arrivals, fact_in_mart.fact_arrivals,
       mart.anomalies_14d, missing.missing_days
FROM fsc, evt, mart, fact_in_mart, missing;