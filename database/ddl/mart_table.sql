/* =====================================================================
   [사전 작업] mart.port_daily_kpi v2 (1회 실행)
   1. master.dim_calendar : 날짜 dim (요일, 주말, 공휴일)
   2. mart.port_daily_kpi : 공휴일·전년 동기 컬럼 추가
   ===================================================================== */


/* =====================================================================
   1. master.dim_calendar
      2025-01-01 ~ 2027-12-31
      공휴일: 관공서의 공휴일에 관한 규정 기준 (대체·임시공휴일, 선거일 포함)
      ※ 공공데이터포털 '한국천문연구원 특일 정보' API로 한 번 대조 권장
   ===================================================================== */
CREATE TABLE IF NOT EXISTS master.dim_calendar (
    cal_date      date PRIMARY KEY,
    year          int  NOT NULL,
    month         int  NOT NULL,
    day_of_week   int  NOT NULL,          -- 1=월 … 7=일 (ISO)
    day_name      varchar(3) NOT NULL,    -- 월 화 수 목 금 토 일
    is_weekend    boolean NOT NULL,
    is_holiday    boolean NOT NULL DEFAULT false,
    holiday_name  varchar(100),
    holiday_group varchar(50)             -- 설날 / 추석 / 기타 공휴일 (연휴 묶음 분석용)
);

COMMENT ON TABLE master.dim_calendar IS '날짜 dim. 공휴일은 관공서 공휴일 규정 기준 (대체·임시공휴일, 선거일 포함)';

INSERT INTO master.dim_calendar (cal_date, year, month, day_of_week, day_name, is_weekend)
SELECT d::date,
       EXTRACT(YEAR    FROM d)::int,
       EXTRACT(MONTH   FROM d)::int,
       EXTRACT(ISODOW  FROM d)::int,
       (ARRAY['월','화','수','목','금','토','일'])[EXTRACT(ISODOW FROM d)::int],
       EXTRACT(ISODOW FROM d) IN (6, 7)
FROM generate_series(DATE '2025-01-01', DATE '2027-12-31', INTERVAL '1 day') d
ON CONFLICT (cal_date) DO NOTHING;

UPDATE master.dim_calendar c
SET is_holiday = true, holiday_name = h.name, holiday_group = h.grp
FROM (VALUES
    /* 2025 */
    (DATE '2025-01-01', '신정',              '기타 공휴일'),
    (DATE '2025-01-27', '임시공휴일',        '설날'),
    (DATE '2025-01-28', '설날 연휴',         '설날'),
    (DATE '2025-01-29', '설날',              '설날'),
    (DATE '2025-01-30', '설날 연휴',         '설날'),
    (DATE '2025-03-01', '삼일절',            '기타 공휴일'),
    (DATE '2025-03-03', '대체공휴일(삼일절)', '기타 공휴일'),
    (DATE '2025-05-05', '어린이날·부처님오신날', '기타 공휴일'),
    (DATE '2025-05-06', '대체공휴일',        '기타 공휴일'),
    (DATE '2025-06-03', '대통령선거일',      '기타 공휴일'),
    (DATE '2025-06-06', '현충일',            '기타 공휴일'),
    (DATE '2025-08-15', '광복절',            '기타 공휴일'),
    (DATE '2025-10-03', '개천절',            '기타 공휴일'),
    (DATE '2025-10-05', '추석 연휴',         '추석'),
    (DATE '2025-10-06', '추석',              '추석'),
    (DATE '2025-10-07', '추석 연휴',         '추석'),
    (DATE '2025-10-08', '대체공휴일(추석)',  '추석'),
    (DATE '2025-10-09', '한글날',            '기타 공휴일'),
    (DATE '2025-12-25', '성탄절',            '기타 공휴일'),
    /* 2026 */
    (DATE '2026-01-01', '신정',              '기타 공휴일'),
    (DATE '2026-02-16', '설날 연휴',         '설날'),
    (DATE '2026-02-17', '설날',              '설날'),
    (DATE '2026-02-18', '설날 연휴',         '설날'),
    (DATE '2026-03-01', '삼일절',            '기타 공휴일'),
    (DATE '2026-03-02', '대체공휴일(삼일절)', '기타 공휴일'),
    (DATE '2026-05-05', '어린이날',          '기타 공휴일'),
    (DATE '2026-05-24', '부처님오신날',      '기타 공휴일'),
    (DATE '2026-05-25', '대체공휴일(부처님오신날)', '기타 공휴일'),
    (DATE '2026-06-03', '전국동시지방선거일', '기타 공휴일'),
    (DATE '2026-06-06', '현충일',            '기타 공휴일'),
    (DATE '2026-08-15', '광복절',            '기타 공휴일'),
    (DATE '2026-08-17', '대체공휴일(광복절)', '기타 공휴일'),
    (DATE '2026-09-24', '추석 연휴',         '추석'),
    (DATE '2026-09-25', '추석',              '추석'),
    (DATE '2026-09-26', '추석 연휴',         '추석'),
    (DATE '2026-10-03', '개천절',            '기타 공휴일'),
    (DATE '2026-10-05', '대체공휴일(개천절)', '기타 공휴일'),
    (DATE '2026-10-09', '한글날',            '기타 공휴일'),
    (DATE '2026-12-25', '성탄절',            '기타 공휴일')
) AS h(d, name, grp)
WHERE c.cal_date = h.d;


/* =====================================================================
   2. mart.port_daily_kpi 컬럼 추가
   ===================================================================== */
ALTER TABLE mart.port_daily_kpi
    ADD COLUMN IF NOT EXISTS day_of_week        int,
    ADD COLUMN IF NOT EXISTS is_weekend         boolean,
    ADD COLUMN IF NOT EXISTS is_holiday         boolean,
    ADD COLUMN IF NOT EXISTS holiday_name       varchar(100),
    ADD COLUMN IF NOT EXISTS ly_date            date,           -- 전년 비교 날짜 (364일 전, 같은 요일). 미수집이면 NULL
    ADD COLUMN IF NOT EXISTS ly_holiday_name    varchar(100),   -- 전년 비교 날짜의 공휴일 (공휴일 날짜가 해마다 달라 비교 시 참고)
    ADD COLUMN IF NOT EXISTS arrivals_ly        int,            -- 364일 전(같은 요일) 입항. 작년 데이터 없으면 NULL
    ADD COLUMN IF NOT EXISTS departures_ly      int,
    ADD COLUMN IF NOT EXISTS arrivals_yoy_pct   numeric(10,1),
    ADD COLUMN IF NOT EXISTS departures_yoy_pct numeric(10,1);

COMMENT ON COLUMN mart.port_daily_kpi.arrivals_ly      IS '364일 전(같은 요일) 입항 수. 그날 데이터를 수집하지 않았으면 NULL';
COMMENT ON COLUMN mart.port_daily_kpi.arrivals_yoy_pct IS '전년 동기(364일 전, 같은 요일) 대비 증감률(%)';
COMMENT ON COLUMN mart.port_daily_kpi.history_days     IS '28일 기준선에 쓴 과거 일수 (수집된 날만)';
COMMENT ON COLUMN mart.port_daily_kpi.is_anomaly       IS '직전 28일(수집된 날) 대비 |z| ≥ 3. 평소 3건 이상 또는 당일 10건 이상일 때만 판정. 공휴일은 판정에 반영하지 않고 표시만';
COMMENT ON COLUMN mart.port_daily_kpi.holiday_name     IS '공휴일명. 이상징후 판단 참고용 (계산에는 미반영)';




/* =====================================================================
   [사전 작업] mart.port_daily_kpi 생성 (1회 실행)

   grain : 항만(port_code) × 날짜(kpi_date, 한국 시간 기준) 1행
   원천  : fact.fact_ship_call, master.dim_mof_port_code (raw는 읽지 않음)
   적재  : mart_port_daily_kpi_load.sql (매번 전체 재계산)
   ===================================================================== */

CREATE SCHEMA IF NOT EXISTS mart;

CREATE TABLE IF NOT EXISTS mart.port_daily_kpi (
    port_code                 varchar(10)  NOT NULL,
    kpi_date                  date         NOT NULL,
    port_name                 varchar(100),
    region_key                varchar(100),

    /* 일별 실적 */
    arrivals                  int          NOT NULL,   -- 입항 선박 수 (대표 입항일, 중복 신고 제외)
    departures                int          NOT NULL,   -- 출항 선박 수 (대표 출항일, 중복 신고 제외)
    arrivals_with_tonnage     int          NOT NULL,   -- 톤수가 있는 입항 수 (평균 톤수의 분모)
    sum_gross_tonnage         numeric,                 -- 입항 선박 총톤수 합
    avg_gross_tonnage         numeric(14,1),           -- 입항 선박 평균 총톤수

    /* 최근 평균 대비 (직전 7일, 당일 제외) */
    arrivals_avg_7d           numeric(10,2),
    arrivals_chg_pct_7d       numeric(10,1),           -- (당일 - 7일 평균) / 7일 평균 × 100
    departures_avg_7d         numeric(10,2),
    departures_chg_pct_7d     numeric(10,1),
    avg_gross_tonnage_7d      numeric(14,1),           -- 직전 7일 입항 선박 평균 총톤수 (톤수 합 / 척수)
    avg_gross_tonnage_chg_pct_7d numeric(10,1),

    /* 이상징후 (직전 28일 기준 z-score) */
    history_days              int,                     -- 판정에 쓴 과거 일수 (최대 28)
    arrivals_mean_28d         numeric(10,2),
    arrivals_sd_28d           numeric(10,2),
    arrivals_zscore           numeric(10,2),
    departures_mean_28d       numeric(10,2),
    departures_sd_28d         numeric(10,2),
    departures_zscore         numeric(10,2),
    is_complete_day           boolean      NOT NULL,   -- 오늘(수집 중)은 false → 이상징후 판정 제외
    is_anomaly                boolean      NOT NULL,
    anomaly_reason            varchar(500),

    refreshed_at              timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_port_daily_kpi PRIMARY KEY (port_code, kpi_date)
);

CREATE INDEX IF NOT EXISTS ix_port_daily_kpi_date    ON mart.port_daily_kpi (kpi_date);
CREATE INDEX IF NOT EXISTS ix_port_daily_kpi_anomaly ON mart.port_daily_kpi (kpi_date) WHERE is_anomaly;

COMMENT ON TABLE  mart.port_daily_kpi                     IS '항만별 일별 입출항 KPI (fact.fact_ship_call 기준, 매번 전체 재계산)';
COMMENT ON COLUMN mart.port_daily_kpi.arrivals            IS '대표 입항일 기준 입항 선박 수. 중복 신고(duplicate_of_ship_call_raw_id 있음) 제외. 입항 0건인 날도 행 존재';
COMMENT ON COLUMN mart.port_daily_kpi.departures          IS '대표 출항일 기준 출항 선박 수. 중복 신고 제외';
COMMENT ON COLUMN mart.port_daily_kpi.avg_gross_tonnage   IS '당일 입항 선박의 평균 총톤수(GT). 톤수 미상 선박 제외';
COMMENT ON COLUMN mart.port_daily_kpi.arrivals_chg_pct_7d IS '직전 7일 평균 대비 증감률(%). 7일 평균이 0이면 NULL';
COMMENT ON COLUMN mart.port_daily_kpi.arrivals_zscore     IS '(당일 - 직전 28일 평균) / 직전 28일 표준편차';
COMMENT ON COLUMN mart.port_daily_kpi.is_anomaly          IS '입항 또는 출항이 직전 28일 대비 |z| ≥ 3 (과거 14일 이상, 물동량 기준 충족 시)';
COMMENT ON COLUMN mart.port_daily_kpi.is_complete_day     IS '오늘(수집 중인 날)은 false';