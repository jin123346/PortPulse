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



/* =====================================================================
   fact.fact_ship_call — 최종 구조 (v10 기준, 2026-10-06)
   v5~v10 setup의 ALTER를 모두 반영한 CREATE문. 새 DB를 처음 세팅할 때 사용.
   ※ 기존 컬럼 타입(varchar 길이 등)은 대화 중 재구성한 값이라,
     운영 DB와 다를 수 있음 → 운영 기준 DDL은 DBeaver에서 테이블 우클릭 > Generate SQL > DDL 로 확인
   ===================================================================== */

CREATE SCHEMA IF NOT EXISTS fact;

CREATE TABLE IF NOT EXISTS fact.fact_ship_call (
    ship_call_id                  bigserial    PRIMARY KEY,   -- fact 대리키
    ship_call_raw_id              bigint       NOT NULL,      -- raw.mof_ship_call.raw_id (UPSERT 키)
    control_call_raw_id           bigint,                     -- 매칭된 raw.mof_control_call (없으면 NULL)

    /* 신고 기본 정보 */
    port_code                     varchar(10),
    port_name                     varchar(50),
    etrypt_year                   varchar(4),
    etrypt_co                     varchar(10),
    clsgn                         varchar(20),
    vessel_name                   varchar(100),
    vessel_kind_cd                varchar(20),                -- v10
    gross_tonnage                 numeric,                    -- v10
    ibobprt_nm                    varchar(50),

    /* 관제 측 입항일시 */
    aprtf_etrypt_dt               timestamp,

    /* 신고 시각 */
    reported_arrival_dt           timestamp,
    arrival_request_type          varchar(10),
    reported_departure_dt         timestamp,
    departure_request_type        varchar(10),

    /* 관제 실측 시각 */
    actual_arrival_dt             timestamp,
    actual_departure_dt           timestamp,

    /* 대표 시각 (v9: 최종 신고 → 관제 실측 → 확정 전 신고) */
    arrival_dt                    timestamp,
    arrival_source                varchar(20),
    departure_dt                  timestamp,
    departure_source              varchar(20),
    stay_minutes                  bigint,

    /* 마지막 관제 상태 */
    last_control_event            varchar(10),
    last_control_event_dt         timestamp,
    last_facility_code            varchar(10),
    last_facility_sub_code        varchar(10),
    last_facility_name            varchar(50),

    /* 매칭 · 품질 표시 */
    control_expected              boolean,                    -- v5
    control_match_priority        smallint,                   -- v6/v7
    suspected_duplicate           boolean,                    -- v8
    duplicate_of_ship_call_raw_id bigint,                     -- v8

    created_at                    timestamp    DEFAULT CURRENT_TIMESTAMP,
    updated_at                    timestamp    DEFAULT CURRENT_TIMESTAMP
);

/* UPSERT 충돌 키 (ON CONFLICT (ship_call_raw_id)) */
CREATE UNIQUE INDEX IF NOT EXISTS uq_fact_ship_call_raw_id
    ON fact.fact_ship_call (ship_call_raw_id);

CREATE INDEX IF NOT EXISTS ix_fact_ship_call_clsgn
    ON fact.fact_ship_call (clsgn, arrival_dt);

/* mart 집계용 (v10) */
CREATE INDEX IF NOT EXISTS ix_fact_ship_call_port_arrival
    ON fact.fact_ship_call (port_code, arrival_dt);
CREATE INDEX IF NOT EXISTS ix_fact_ship_call_port_departure
    ON fact.fact_ship_call (port_code, departure_dt);


COMMENT ON TABLE  fact.fact_ship_call IS '입출항 신고 1건 = 1행. 신고(raw.mof_ship_call)와 VTS 관제(raw.mof_control_call) 매칭 결과';
COMMENT ON COLUMN fact.fact_ship_call.ship_call_raw_id IS 'raw.mof_ship_call.raw_id. 적재 UPSERT 키';
COMMENT ON COLUMN fact.fact_ship_call.control_call_raw_id IS '매칭된 관제 raw id. 관제 1건은 신고 1건에만 매칭(1:1)';
COMMENT ON COLUMN fact.fact_ship_call.arrival_dt IS '대표 입항시각: 최종 신고 → 관제 실측 → 확정 전 신고 순';
COMMENT ON COLUMN fact.fact_ship_call.departure_dt IS '대표 출항시각: 대표 입항 이후 값만, 우선순위는 입항과 동일';
COMMENT ON COLUMN fact.fact_ship_call.control_expected IS '관제 대상 여부 (master.dim_mof_vessel_kind 기준). false면 관제 미매칭이 정상';
COMMENT ON COLUMN fact.fact_ship_call.control_match_priority IS
    '관제 매칭 등급(v7). 1 입항횟수 일치+6시간 이내, 2 같은 항구+시각 일치, 3 같은 권역+시각 일치, '
    '4 입항횟수 어긋남+시각 일치, 5 입항횟수 일치+6시간 초과(출항 후 관제 제외), 6 같은 권역+±60분 근사. NULL = 미매칭';
COMMENT ON COLUMN fact.fact_ship_call.suspected_duplicate IS '중복 신고 의심 그룹에 속함 (같은 호출부호, 입항 60분 이내, 체류 기간 겹침)';
COMMENT ON COLUMN fact.fact_ship_call.duplicate_of_ship_call_raw_id IS '대표 신고의 raw id. 값이 있으면 중복(대표 아님) → mart 집계에서 제외';
COMMENT ON COLUMN fact.fact_ship_call.gross_tonnage IS '총톤수(GT). 입항 신고 grtg → 출항 신고 grtg → 관제 vssl_grtg 순. 0이나 숫자가 아니면 NULL';
COMMENT ON COLUMN fact.fact_ship_call.vessel_kind_cd IS '선박 종류 코드 (master.dim_mof_vessel_kind)';
