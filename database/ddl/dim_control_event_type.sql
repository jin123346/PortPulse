* =====================================================================
   1. master.dim_control_event_type
      - raw에 있는 (cntrl_se, cntrl_nm)으로 초기 적재
      - event_group    : 이름이 조금 달라도 같은 성격이면 같은 그룹 (mart 집계용)
      - location_after : 이 이벤트 다음에 배가 있는 곳 (다음 이벤트까지의 시간을 어디에 쓸지)
                         입항은 NULL = 입항 시설(정박지/부두)로 판단
      - 이름 규칙으로 분류하지 못한 코드는 '기타' → 모니터링 12번에서 확인 후 직접 수정
   ===================================================================== */
CREATE TABLE IF NOT EXISTS master.dim_control_event_type (
    event_code      varchar(100) PRIMARY KEY,           -- cntrl_se
    event_name      varchar(200) NOT NULL,              -- cntrl_nm (대표 이름)
    event_group     varchar(50)  NOT NULL DEFAULT '기타',
    location_after  varchar(50),
    sort_order      int,
    note            varchar(500),
    created_at      timestamp DEFAULT CURRENT_TIMESTAMP,
    updated_at      timestamp DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE  master.dim_control_event_type                IS '관제 이벤트 종류 (raw.mof_control_event.cntrl_se)';
COMMENT ON COLUMN master.dim_control_event_type.event_group    IS '입항/투묘/양묘/접안/이안/이동/출항/기타';
COMMENT ON COLUMN master.dim_control_event_type.location_after IS '이벤트 다음에 배가 있는 곳: 정박지/선석/이동/항외. NULL이면 이벤트 시설로 판단';

INSERT INTO master.dim_control_event_type (event_code, event_name, event_group, location_after, sort_order)
SELECT event_code, event_name,
       CASE
           WHEN event_name LIKE '%입항%' THEN '입항'
           WHEN event_name LIKE '%투묘%' THEN '투묘'
           WHEN event_name LIKE '%양묘%' THEN '양묘'
           WHEN event_name LIKE '%이안%' THEN '이안'
           WHEN event_name LIKE '%접안%' THEN '접안'
           WHEN event_name LIKE '%이동%' OR event_name LIKE '%이선%' OR event_name LIKE '%시프트%' THEN '이동'
           WHEN event_name LIKE '%출항%' THEN '출항'
           ELSE '기타'
       END,
       CASE
           WHEN event_name LIKE '%입항%' THEN NULL
           WHEN event_name LIKE '%투묘%' THEN '정박지'
           WHEN event_name LIKE '%양묘%' THEN '이동'
           WHEN event_name LIKE '%이안%' THEN '이동'
           WHEN event_name LIKE '%접안%' THEN '선석'
           WHEN event_name LIKE '%이동%' OR event_name LIKE '%이선%' OR event_name LIKE '%시프트%' THEN '이동'
           WHEN event_name LIKE '%출항%' THEN '항외'
       END,
       CASE
           WHEN event_name LIKE '%입항%' THEN 10
           WHEN event_name LIKE '%투묘%' THEN 20
           WHEN event_name LIKE '%양묘%' THEN 30
           WHEN event_name LIKE '%접안%' AND event_name NOT LIKE '%이안%' THEN 40
           WHEN event_name LIKE '%이안%' THEN 50
           WHEN event_name LIKE '%출항%' THEN 90
           ELSE 60
       END
FROM (
    SELECT cntrl_se AS event_code,
           MODE() WITHIN GROUP (ORDER BY cntrl_nm) AS event_name   -- 코드당 가장 많이 쓰인 이름
    FROM raw.mof_control_event
    WHERE cntrl_se IS NOT NULL AND cntrl_nm IS NOT NULL
    GROUP BY cntrl_se
) x
ON CONFLICT (event_code) DO NOTHING;   -- 이미 있는 코드는 사람이 고친 값 유지


/* =====================================================================
   2. fact.fact_control_event
      grain: 관제 이벤트 1건 (raw.mof_control_event 1행)
      ship_call과는 fact_ship_call.control_call_raw_id로 조인 (여기엔 두지 않음)
   ===================================================================== */
CREATE TABLE IF NOT EXISTS fact.fact_control_event (
    control_event_id     bigserial PRIMARY KEY,
    control_event_raw_id bigint      NOT NULL,          -- raw.mof_control_event PK
    control_call_raw_id  bigint      NOT NULL,          -- fact_ship_call 조인 키
    event_seq            int,                           -- comm_co (같은 관제 안의 순번)
    event_code           varchar(100),                  -- cntrl_se → master.dim_control_event_type
    event_name           varchar(200),                  -- cntrl_nm (원문)
    event_dt             timestamp,                     -- cntrl_opert_dt (한국 시간)
    facility_code        varchar(50),
    facility_sub_code    varchar(50),
    facility_name        varchar(200),
    is_first_event       boolean,                       -- 관제의 첫 이벤트
    is_last_event        boolean,                       -- 관제의 마지막 이벤트 (아직 진행 중일 수 있음)
    next_event_raw_id    bigint,                        -- 같은 관제의 다음 이벤트
    next_event_dt        timestamp,
    minutes_to_next      bigint,                        -- 다음 이벤트까지 걸린 시간(분). 마지막 이벤트는 NULL
    created_at           timestamp DEFAULT CURRENT_TIMESTAMP,
    updated_at           timestamp DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_fact_control_event_raw UNIQUE (control_event_raw_id)
);

CREATE INDEX IF NOT EXISTS ix_fact_control_event_call
    ON fact.fact_control_event (control_call_raw_id, event_seq);

COMMENT ON TABLE  fact.fact_control_event                 IS '관제 이벤트 1건 = 1행. ship_call과는 fact_ship_call.control_call_raw_id로 조인';
COMMENT ON COLUMN fact.fact_control_event.event_seq       IS '같은 관제 안의 순번 (raw comm_co)';
COMMENT ON COLUMN fact.fact_control_event.event_dt        IS '관제작업일시 (한국 시간, timestamp)';
COMMENT ON COLUMN fact.fact_control_event.minutes_to_next IS '다음 이벤트까지 걸린 시간(분). 예: 입항→양묘 = 정박지 대기, 접안→출항 = 접안 시간';
COMMENT ON COLUMN fact.fact_control_event.is_last_event   IS '관제의 마지막 이벤트. 출항이 아니면 아직 진행 중';