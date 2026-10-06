/* =====================================================================
   mart.port_daily_kpi 적재 v2 (매번 전체 재계산)

   [실행 전 확인]
   - mart_port_daily_kpi_setup.sql, mart_port_daily_kpi_v2_setup.sql 1회 실행 완료
   - fact.fact_ship_call 적재(v10) 후 실행
   - 스크립트 전체 실행(Alt+X). Auto-Commit 켜짐/꺼짐 모두 동작

   [계산 기준]
   - 날짜: 한국 시간. 수집된 날(전국 입항이 일별 중앙값의 20% 이상인 날, params.min_collected_ratio)만 행을 만듦
           → 수집하지 않은 기간(예: 2025-10 ~ 2026-07)은 행 없음
           수집된 날 안에서는 입항 0건인 항만도 행을 만듦
           미래 날짜(예정 신고)는 제외, 오늘은 is_complete_day = false
   - 중복 신고(duplicate_of_ship_call_raw_id 있음)는 집계에서 제외
   - 평균은 날짜 범위 기준 (행 개수 기준이 아님 → 수집 공백을 건너뛰어 섞이지 않음)
   - 증감률: 직전 7일(당일 제외) 중 수집된 날의 평균 대비
   - 전년 동기: 364일 전(같은 요일). 그날을 수집하지 않았으면 NULL
   - 공휴일: 계산에는 반영하지 않고 표시만 함 (holiday_name, 사유의 [공휴일명], 작년 그날의 공휴일)
           → 해마다 날짜가 다르므로 판단은 보는 사람이 표시를 보고 함
   - 이상징후: 직전 28일(당일 제외) 중 수집된 날의 평균·표준편차로 z-score
       |z| ≥ z_threshold, 기준선 일수 ≥ min_history_days,
       28일 평균 ≥ min_baseline_volume 또는 당일 ≥ min_spike_volume 일 때만 판정
       표준편차가 0이면 평균과 다를 때 이상징후
       공휴일이면 사유 끝에 [공휴일명] 표시
   - 판정 기준값은 아래 params에서 조정
   ===================================================================== */

SET TIME ZONE 'Asia/Seoul';

BEGIN;

DROP TABLE IF EXISTS tmp_port_daily_kpi;
CREATE TEMP TABLE tmp_port_daily_kpi AS
WITH params AS (
    SELECT 3.0::numeric  AS z_threshold,          -- 이상징후 z-score 기준
           14            AS min_history_days,     -- 기준선에 필요한 최소 일수 (수집된 날 기준)
           3.0::numeric  AS min_baseline_volume,  -- 평소(28일 평균)가 이 이상이면 판정
           10            AS min_spike_volume,     -- 또는 당일이 이 이상이면 판정 (소량 항만 급증)
           0.2::numeric  AS min_collected_ratio   -- 전국 입항이 일별 중앙값의 20% 이상인 날만 '수집된 날'
),
calls AS (
    SELECT port_code, port_name, arrival_dt, departure_dt, gross_tonnage
    FROM fact.fact_ship_call
    WHERE duplicate_of_ship_call_raw_id IS NULL
),
daily_total AS (
    /* 전 항만 합계 일별 입항 (오늘까지) */
    SELECT arrival_dt::date AS kpi_date, COUNT(*) AS total_arrivals
    FROM calls
    WHERE arrival_dt IS NOT NULL
      AND arrival_dt::date <= CURRENT_DATE
    GROUP BY 1
),
data_dates AS (
    /* 수집된 날: 전국 입항이 일별 중앙값의 일정 비율 이상인 날
       → 미수집 기간에 섞여 들어온 몇 건(장기 체류 선박 등)이 '수집된 날'로 잡히지 않게 함 */
    SELECT d.kpi_date
    FROM daily_total d
    CROSS JOIN params p
    WHERE d.total_arrivals >= p.min_collected_ratio
                              * (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY total_arrivals) FROM daily_total)
),
ports AS (
    SELECT c.port_code,
           COALESCE(MAX(p.prt_ag_nm), MAX(c.port_name)) AS port_name,
           MAX(p.region_key)                            AS region_key
    FROM calls c
    LEFT JOIN master.dim_mof_port_code p ON p.prt_ag_cd = c.port_code
    WHERE c.port_code IS NOT NULL
    GROUP BY c.port_code
),
calendar AS (
    SELECT pt.port_code, pt.port_name, pt.region_key, dd.kpi_date,
           COALESCE(cal.day_of_week, EXTRACT(ISODOW FROM dd.kpi_date)::int) AS day_of_week,
           COALESCE(cal.is_weekend,  EXTRACT(ISODOW FROM dd.kpi_date) IN (6, 7)) AS is_weekend,
           COALESCE(cal.is_holiday, false)                                  AS is_holiday,
           cal.holiday_name
    FROM ports pt
    CROSS JOIN data_dates dd
    LEFT JOIN master.dim_calendar cal ON cal.cal_date = dd.kpi_date
),
arr AS (
    SELECT port_code, arrival_dt::date AS kpi_date,
           COUNT(*)                AS arrivals,
           COUNT(gross_tonnage)    AS arrivals_with_tonnage,
           SUM(gross_tonnage)      AS sum_gross_tonnage
    FROM calls
    WHERE arrival_dt IS NOT NULL
    GROUP BY 1, 2
),
dep AS (
    SELECT port_code, departure_dt::date AS kpi_date, COUNT(*) AS departures
    FROM calls
    WHERE departure_dt IS NOT NULL
    GROUP BY 1, 2
),
daily AS (
    SELECT c.*,
           COALESCE(a.arrivals, 0)              AS arrivals,
           COALESCE(d.departures, 0)            AS departures,
           COALESCE(a.arrivals_with_tonnage, 0) AS arrivals_with_tonnage,
           a.sum_gross_tonnage,
           (c.kpi_date < CURRENT_DATE)          AS is_complete_day
    FROM calendar c
    LEFT JOIN arr a ON a.port_code = c.port_code AND a.kpi_date = c.kpi_date
    LEFT JOIN dep d ON d.port_code = c.port_code AND d.kpi_date = c.kpi_date
),
windowed AS (
    SELECT dl.*,
           AVG(arrivals)               OVER w7  AS arrivals_avg_7d,
           AVG(departures)             OVER w7  AS departures_avg_7d,
           SUM(sum_gross_tonnage)      OVER w7  AS sum_gt_7d,
           SUM(arrivals_with_tonnage)  OVER w7  AS n_gt_7d,
           COUNT(*)                OVER w28 AS history_days,
           AVG(arrivals)           OVER w28 AS arrivals_mean_28d,
           STDDEV_SAMP(arrivals)   OVER w28 AS arrivals_sd_28d,
           AVG(departures)         OVER w28 AS departures_mean_28d,
           STDDEV_SAMP(departures) OVER w28 AS departures_sd_28d
    FROM daily dl
    WINDOW w7  AS (PARTITION BY port_code ORDER BY kpi_date
                   RANGE BETWEEN INTERVAL '7 days'  PRECEDING AND INTERVAL '1 day' PRECEDING),
           w28 AS (PARTITION BY port_code ORDER BY kpi_date
                   RANGE BETWEEN INTERVAL '28 days' PRECEDING AND INTERVAL '1 day' PRECEDING)
),
scored AS (
    SELECT w.*,
           sum_gross_tonnage / NULLIF(arrivals_with_tonnage, 0)              AS avg_gross_tonnage,
           sum_gt_7d / NULLIF(n_gt_7d, 0)                                    AS avg_gross_tonnage_7d,
           (arrivals   - arrivals_mean_28d)   / NULLIF(arrivals_sd_28d, 0)   AS arrivals_zscore,
           (departures - departures_mean_28d) / NULLIF(departures_sd_28d, 0) AS departures_zscore
    FROM windowed w
),
flagged AS (
    SELECT s.*,
           (    s.is_complete_day
            AND s.history_days >= p.min_history_days
            AND (s.arrivals_mean_28d >= p.min_baseline_volume OR s.arrivals >= p.min_spike_volume)
            AND (   ABS(s.arrivals_zscore) >= p.z_threshold
                 OR (COALESCE(s.arrivals_sd_28d, 0) = 0 AND s.arrivals <> s.arrivals_mean_28d))
           ) AS arr_anomaly,
           (    s.is_complete_day
            AND s.history_days >= p.min_history_days
            AND (s.departures_mean_28d >= p.min_baseline_volume OR s.departures >= p.min_spike_volume)
            AND (   ABS(s.departures_zscore) >= p.z_threshold
                 OR (COALESCE(s.departures_sd_28d, 0) = 0 AND s.departures <> s.departures_mean_28d))
           ) AS dep_anomaly
    FROM scored s
    CROSS JOIN params p
)
SELECT
    f.port_code, f.kpi_date, f.port_name, f.region_key,
    f.day_of_week, f.is_weekend, f.is_holiday, f.holiday_name,
    f.arrivals, f.departures, f.arrivals_with_tonnage,
    f.sum_gross_tonnage,
    ROUND(f.avg_gross_tonnage, 1)                                                         AS avg_gross_tonnage,
    ROUND(f.arrivals_avg_7d, 2)                                                           AS arrivals_avg_7d,
    ROUND((f.arrivals - f.arrivals_avg_7d) / NULLIF(f.arrivals_avg_7d, 0) * 100, 1)       AS arrivals_chg_pct_7d,
    ROUND(f.departures_avg_7d, 2)                                                         AS departures_avg_7d,
    ROUND((f.departures - f.departures_avg_7d) / NULLIF(f.departures_avg_7d, 0) * 100, 1) AS departures_chg_pct_7d,
    ROUND(f.avg_gross_tonnage_7d, 1)                                                      AS avg_gross_tonnage_7d,
    ROUND((f.avg_gross_tonnage - f.avg_gross_tonnage_7d) / NULLIF(f.avg_gross_tonnage_7d, 0) * 100, 1) AS avg_gross_tonnage_chg_pct_7d,
    /* 전년 동기: 364일 전 같은 요일. 그날 행이 없으면(미수집) NULL */
    ly.kpi_date                                                                           AS ly_date,
    ly.holiday_name                                                                       AS ly_holiday_name,
    ly.arrivals                                                                           AS arrivals_ly,
    ly.departures                                                                         AS departures_ly,
    ROUND((f.arrivals   - ly.arrivals)   / NULLIF(ly.arrivals,   0)::numeric * 100, 1)    AS arrivals_yoy_pct,
    ROUND((f.departures - ly.departures) / NULLIF(ly.departures, 0)::numeric * 100, 1)    AS departures_yoy_pct,
    f.history_days::int                                                                   AS history_days,
    ROUND(f.arrivals_mean_28d, 2)   AS arrivals_mean_28d,
    ROUND(f.arrivals_sd_28d, 2)     AS arrivals_sd_28d,
    ROUND(f.arrivals_zscore, 2)     AS arrivals_zscore,
    ROUND(f.departures_mean_28d, 2) AS departures_mean_28d,
    ROUND(f.departures_sd_28d, 2)   AS departures_sd_28d,
    ROUND(f.departures_zscore, 2)   AS departures_zscore,
    f.is_complete_day,
    COALESCE(f.arr_anomaly OR f.dep_anomaly, false)                                       AS is_anomaly,
    NULLIF(concat_ws('; ',
        CASE WHEN f.arr_anomaly THEN
            '입항 ' || CASE WHEN f.arrivals > f.arrivals_mean_28d THEN '급증' ELSE '급감' END
            || ': ' || f.arrivals || '건 (최근 28일 평균 ' || ROUND(f.arrivals_mean_28d, 1) || '건)' END,
        CASE WHEN f.dep_anomaly THEN
            '출항 ' || CASE WHEN f.departures > f.departures_mean_28d THEN '급증' ELSE '급감' END
            || ': ' || f.departures || '건 (최근 28일 평균 ' || ROUND(f.departures_mean_28d, 1) || '건)' END
    ) || CASE WHEN (f.arr_anomaly OR f.dep_anomaly) AND f.is_holiday
              THEN ' [' || f.holiday_name || ']' ELSE '' END, '')                         AS anomaly_reason
FROM flagged f
LEFT JOIN daily ly
       ON ly.port_code = f.port_code
      AND ly.kpi_date  = f.kpi_date - 364;

ANALYZE tmp_port_daily_kpi;

/* 기간 밖으로 밀려난 행 삭제 (항만 코드가 사라졌거나 시작일이 바뀐 경우) */
DELETE FROM mart.port_daily_kpi m
WHERE NOT EXISTS (
    SELECT 1 FROM tmp_port_daily_kpi t
    WHERE t.port_code = m.port_code AND t.kpi_date = m.kpi_date
);

/* UPSERT (적재 중에도 테이블이 비지 않음) */
INSERT INTO mart.port_daily_kpi AS m (
    port_code, kpi_date, port_name, region_key,
    day_of_week, is_weekend, is_holiday, holiday_name,
    ly_date, ly_holiday_name, arrivals_ly, departures_ly, arrivals_yoy_pct, departures_yoy_pct,
    arrivals, departures, arrivals_with_tonnage, sum_gross_tonnage, avg_gross_tonnage,
    arrivals_avg_7d, arrivals_chg_pct_7d, departures_avg_7d, departures_chg_pct_7d,
    avg_gross_tonnage_7d, avg_gross_tonnage_chg_pct_7d,
    history_days, arrivals_mean_28d, arrivals_sd_28d, arrivals_zscore,
    departures_mean_28d, departures_sd_28d, departures_zscore,
    is_complete_day, is_anomaly, anomaly_reason, refreshed_at
)
SELECT
    port_code, kpi_date, port_name, region_key,
    day_of_week, is_weekend, is_holiday, holiday_name,
    ly_date, ly_holiday_name, arrivals_ly, departures_ly, arrivals_yoy_pct, departures_yoy_pct,
    arrivals, departures, arrivals_with_tonnage, sum_gross_tonnage, avg_gross_tonnage,
    arrivals_avg_7d, arrivals_chg_pct_7d, departures_avg_7d, departures_chg_pct_7d,
    avg_gross_tonnage_7d, avg_gross_tonnage_chg_pct_7d,
    history_days, arrivals_mean_28d, arrivals_sd_28d, arrivals_zscore,
    departures_mean_28d, departures_sd_28d, departures_zscore,
    is_complete_day, is_anomaly, anomaly_reason, CURRENT_TIMESTAMP
FROM tmp_port_daily_kpi
ON CONFLICT (port_code, kpi_date)
DO UPDATE SET
    port_name                    = EXCLUDED.port_name,
    day_of_week                  = EXCLUDED.day_of_week,
    is_weekend                   = EXCLUDED.is_weekend,
    is_holiday                   = EXCLUDED.is_holiday,
    holiday_name                 = EXCLUDED.holiday_name,
    ly_date                      = EXCLUDED.ly_date,
    ly_holiday_name              = EXCLUDED.ly_holiday_name,
    arrivals_ly                  = EXCLUDED.arrivals_ly,
    departures_ly                = EXCLUDED.departures_ly,
    arrivals_yoy_pct             = EXCLUDED.arrivals_yoy_pct,
    departures_yoy_pct           = EXCLUDED.departures_yoy_pct,
    region_key                   = EXCLUDED.region_key,
    arrivals                     = EXCLUDED.arrivals,
    departures                   = EXCLUDED.departures,
    arrivals_with_tonnage        = EXCLUDED.arrivals_with_tonnage,
    sum_gross_tonnage            = EXCLUDED.sum_gross_tonnage,
    avg_gross_tonnage            = EXCLUDED.avg_gross_tonnage,
    arrivals_avg_7d              = EXCLUDED.arrivals_avg_7d,
    arrivals_chg_pct_7d          = EXCLUDED.arrivals_chg_pct_7d,
    departures_avg_7d            = EXCLUDED.departures_avg_7d,
    departures_chg_pct_7d        = EXCLUDED.departures_chg_pct_7d,
    avg_gross_tonnage_7d         = EXCLUDED.avg_gross_tonnage_7d,
    avg_gross_tonnage_chg_pct_7d = EXCLUDED.avg_gross_tonnage_chg_pct_7d,
    history_days                 = EXCLUDED.history_days,
    arrivals_mean_28d            = EXCLUDED.arrivals_mean_28d,
    arrivals_sd_28d              = EXCLUDED.arrivals_sd_28d,
    arrivals_zscore              = EXCLUDED.arrivals_zscore,
    departures_mean_28d          = EXCLUDED.departures_mean_28d,
    departures_sd_28d            = EXCLUDED.departures_sd_28d,
    departures_zscore            = EXCLUDED.departures_zscore,
    is_complete_day              = EXCLUDED.is_complete_day,
    is_anomaly                   = EXCLUDED.is_anomaly,
    anomaly_reason               = EXCLUDED.anomaly_reason,
    refreshed_at                 = EXCLUDED.refreshed_at;

COMMIT;
