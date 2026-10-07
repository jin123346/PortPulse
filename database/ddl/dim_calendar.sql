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
