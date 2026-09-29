create schema if not exists raw;
create schema if not exists master;
create schema if not exists mart;

CREATE SCHEMA IF NOT EXISTS audit;

CREATE TABLE audit.pipeline_run (
    run_id BIGSERIAL PRIMARY KEY,

    pipeline_name VARCHAR(100) NOT NULL,
    run_key VARCHAR(255),
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    finished_at TIMESTAMP,

    status VARCHAR(20) NOT NULL DEFAULT 'RUNNING',

    start_date DATE,
    end_date DATE,

    error_message TEXT,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE audit.api_request
ADD CONSTRAINT fk_api_request_pipeline_run
FOREIGN KEY (run_id)
REFERENCES audit.pipeline_run(run_id);


CREATE TABLE audit.api_request (
    api_request_id BIGSERIAL PRIMARY KEY,
    request_id VARCHAR(255) NOT NULL UNIQUE,
    source_type VARCHAR(50) NOT NULL,
    prt_ag_cd VARCHAR(255) NOT NULL,
    page_no INT,
    num_of_rows INT,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    response_count INT,
    total_count INT,
    total_page INT,
    detail_count INT,
    date_type VARCHAR(10),
    status VARCHAR(50),
    request_started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    request_finished_at TIMESTAMP,
    error_message TEXT,
    run_id BIGINT
);

ALTER TABLE audit.api_request
ADD CONSTRAINT fk_api_request_run
FOREIGN KEY (run_id)
REFERENCES audit.pipeline_run(run_id);

create table if not exists raw.mof_ship_call (
    raw_id bigserial primary key,  
    request_id varchar(255) not null, 
    prt_ag_cd varchar(255), --항구청코드
    prt_ag_nm varchar(255), --항구청명
    etrypt_yr varchar(4), --입항년도
    etrypt_co varchar(255), --입항횟수
    clsgn varchar(255), --호출부호
    vssl_nm varchar(255), --선박명
    vssl_nlty_cd varchar(255), --선박국가코드
    vssl_nlty_nm varchar(255), --선박국가명
    vssl_knd_cd varchar(255), --선박종류코드
    vssl_knd_nm varchar(255), --선박종류명
    etrypt_purps_cd varchar(255), --입항목적코드
    etrypt_purps_nm varchar(255), --입항목적명
    frst_dpmprt_nat_prt_cd varchar(255), --최초출항지국가항구코드
    frst_dpmprt_prt_nm varchar(255), --최초출항지항구명
    prvs_dpmprt_nat_prt_cd varchar(255), --전출항지국가항구코드
    prvs_dpmprt_prt_nm varchar(255), --전출항지항구명
    nxlnpt_nat_prt_cd varchar(255), --차항지국가항구코드
    nxlnpt_prt_nm varchar(255), --차출항지항구명
    dstn_nat_prt_cd varchar(255), -- 목적지국가항구코드
    dstn_prt_nm varchar(255), -- 목적지 항구명
    raw_payload JSONB, --원본값
    first_extracted_at timestamp DEFAULT CURRENT_TIMESTAMP, -- 첫번째 추출일,
    update_extracted_at timestamp DEFAULT CURRENT_TIMESTAMP, -- 마지막 추출일(업데이트일)
    CONSTRAINT uq_mof_ship_call
        UNIQUE (
            prt_ag_cd,
            etrypt_yr,
            etrypt_co,
            clsgn
        )
);

api_request_id BIGINT NOT NULL
    REFERENCES audit.api_request(api_request_id)

ALTER TABLE raw.mof_ship_call RENAME COLUMN extracted_at TO first_extracted_at;
ALTER TABLE raw.mof_ship_call ADD update_extracted_at timestamp NULL;

ALTER TABLE raw.mof_ship_call
DROP CONSTRAINT IF EXISTS uq_mof_ship_call;
ALTER TABLE raw.mof_ship_call
ADD CONSTRAINT uq_mof_ship_call
UNIQUE (
    prt_ag_cd,
    etrypt_yr,
    etrypt_co,
    clsgn
);

create table if not exists raw.mof_ship_call_detail(
    detail_raw_id bigserial primary key,
    ship_call_raw_id bigint references raw.mof_ship_call(raw_id), 
    reqst_se_nm varchar(255), --신청구분명
    etrynd_nm varchar(255), --입출항구분명
    etrypt_dt varchar(255), -- 입항일시-입항상세
    tkoff_dt varchar(255), --출항일시-출항상세
    ibobprt_nm varchar(255), --내외항구분명
    laidup_fclty_cd varchar(100), --계선시설코드
    laidup_fclty_sub_cd varchar(100), --계선시설세부코드
    laidup_fclty_nm varchar(255), --계선시설명
    tug_yn varchar(1), --예선유무
    piltg_yn varchar(1), --도선유무
    ldadng_frght_cl_cd varchar(100), --화물명세
    ldadng_ton varchar(255), --적재톤수
    trnpdt_ton varchar(255), --환적톤수
    landng_frght_ton varchar(255), --양하화물톤
    ld_frght_ton varchar(255), --적재화물톤
    grtg varchar(255), --총톤수
    intrl_grtg varchar(255), --국제총톤수
    satmnt_entrps_nm varchar(255), --신고업체명
    crew_co varchar(255), --선원수
    koran_crew_co varchar(255), --한국인선원수
    frgnr_crew_co varchar(255), --외국인선원수
    mr_num varchar(255), --적하목록관리번호
    tkoff_prrrn_dt varchar(255), --출항예정일시
    dstn_etrypt_dt varchar(255), --목적지입항일시
    raw_payload JSONB, --원본값,
    first_created_at timestamp DEFAULT CURRENT_TIMESTAMP, -- 첫번째 추출일
    updated_at timestamp DEFAULT CURRENT_TIMESTAMP,-- 마지막 추출일(업데이트일)
    CONSTRAINT uq_mof_ship_call_detail
        UNIQUE (
            ship_call_raw_id,
            etrynd_nm,
            reqst_se_nm
        )
)
ALTER TABLE raw.mof_ship_call_detail drop constraint IF EXISTS uq_mof_ship_call_detail;
ALTER TABLE raw.mof_ship_call_detail
ADD CONSTRAINT uq_mof_ship_call_detail
UNIQUE (
    ship_call_raw_id,
    etrynd_nm,
    reqst_se_nm
);


ALTER TABLE raw.mof_ship_call
ADD COLUMN arrival_dt TIMESTAMPTZ;

ALTER TABLE raw.mof_ship_call
ALTER COLUMN extracted_at
SET DEFAULT CURRENT_TIMESTAMP;


ALTER TABLE raw.mof_ship_call_detail
ADD COLUMN first_created_at TIMESTAMPTZ default CURRENT_TIMESTAMP,
ADD COLUMN  updated_at TIMESTAMPTZ default CURRENT_TIMESTAMP;

ALTER TABLE raw.mof_ship_call_detail
ADD CONSTRAINT uq_mof_ship_call_detail
UNIQUE (
    ship_call_raw_id,
    etrynd_nm
);

CREATE TABLE if not exists master.international_port  (
    port_code VARCHAR(5) PRIMARY KEY,
    country_code VARCHAR(2) not null,
    location_code VARCHAR(3) NOT NULL,
    port_name VARCHAR(255) NOT NULL,
    country_name_ko VARCHAR(255) NOT NULL,
    active_yn CHAR(1) NOT NULL DEFAULT 'Y',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE if not exists master.domestic_port  (
    port_id VARCHAR(3) PRIMARY KEY,
    port_name VARCHAR(100) NOT NULL,
    sea_area_code numeric(2) NOT NULL,
    port_type_code VARCHAR(10) NOT NULL DEFAULT 'D', -- 'D' for domestic, 'I' for international
    active_yn CHAR(1) NOT NULL DEFAULT 'Y',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP 
);


CREATE TABLE raw.mof_ship_call_detail_history (
    history_id BIGSERIAL PRIMARY KEY,
    detail_id BIGINT NOT NULL,
    etrynd_nm VARCHAR(50),
    old_payload JSONB,
    new_payload JSONB,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE raw.mof_ship_call_history (
    history_id      BIGSERIAL PRIMARY KEY,
    raw_id          BIGINT NOT NULL,
    old_payload     JSONB NOT NULL,
    new_payload     JSONB NOT NULL,
    changed_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (raw_id)
        REFERENCES raw.mof_ship_call(raw_id)
);


--function and trigger for mof_ship_call_history
CREATE OR REPLACE FUNCTION raw.fn_mof_ship_call_history()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.raw_payload IS DISTINCT FROM NEW.raw_payload THEN

        INSERT INTO raw.mof_ship_call_history (
            raw_id,
            old_payload,
            new_payload,
            changed_at
        )
        VALUES (
            OLD.raw_id,
            OLD.raw_payload,
            NEW.raw_payload,
            CURRENT_TIMESTAMP
        );

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_mof_ship_call_history
BEFORE UPDATE ON raw.mof_ship_call
FOR EACH ROW
EXECUTE FUNCTION raw.fn_mof_ship_call_history();




CREATE TABLE raw.mof_control_call (
    control_call_raw_id BIGSERIAL PRIMARY KEY,

    api_request_id BIGINT NOT NULL,

    prt_ag_cd VARCHAR(10),
    prt_ag_nm VARCHAR(100),

    etrypt_year VARCHAR(4),
    etrypt_co VARCHAR(10),

    clsgn VARCHAR(30),
    vssl_knd_cd VARCHAR(20),
    vssl_knd_nm VARCHAR(100),
    vssl_nm VARCHAR(200),
    vssl_grtg NUMERIC,

    vssl_nlty_cd VARCHAR(20),
    vssl_nlty_nm VARCHAR(100),

    vssl_satmnt_ag_cd VARCHAR(20),
    satmnt_etrypt_year VARCHAR(4),
    satmnt_etrypt_co VARCHAR(10),

    aprtf_etrypt_dt TIMESTAMP,
    tkoff_dt TIMESTAMP,

    harbor_entrps_cd VARCHAR(50),
    harbor_entrps_nm VARCHAR(200),

    raw_payload JSONB NOT NULL,

    first_inserted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_mof_control_call
        UNIQUE (
            prt_ag_cd,
            etrypt_year,
            etrypt_co,
            clsgn,
            aprtf_etrypt_dt
        ),

    CONSTRAINT fk_control_call_api_request
        FOREIGN KEY (api_request_id)
        REFERENCES audit.api_request(api_request_id)
);


CREATE TABLE raw.mof_control_event (
    control_event_raw_id BIGSERIAL PRIMARY KEY,

    control_call_raw_id BIGINT NOT NULL,

    cntrl_nm VARCHAR(200),

    etrypt_year VARCHAR(4),
    etrypt_co VARCHAR(10),

    comm_co INTEGER,

    cntrl_se VARCHAR(100),
    cntrl_opert_dt TIMESTAMP,

    fclty_cd VARCHAR(50),
    fclty_sub_cd VARCHAR(50),
    fclty_nm VARCHAR(200),

    raw_payload JSONB NOT NULL,

    first_inserted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_mof_control_event
        UNIQUE (
            control_call_raw_id,
            comm_co
        ),

    CONSTRAINT fk_control_event_call
        FOREIGN KEY (control_call_raw_id)
        REFERENCES raw.mof_control_call(control_call_raw_id)
        ON DELETE CASCADE
);


-- ============================================================
-- raw.mof_control_call
-- ============================================================

COMMENT ON TABLE raw.mof_control_call
IS '해양수산부 선박 관제정보 API의 선박 입출항 단위 원천 데이터';

COMMENT ON COLUMN raw.mof_control_call.control_call_raw_id
IS '관제정보 원천 데이터 내부 식별자(PK)';

COMMENT ON COLUMN raw.mof_control_call.api_request_id
IS 'API 요청 이력 식별자(FK)';

COMMENT ON COLUMN raw.mof_control_call.prt_ag_cd
IS '항구청코드';

COMMENT ON COLUMN raw.mof_control_call.prt_ag_nm
IS '항만명';

COMMENT ON COLUMN raw.mof_control_call.etrypt_year
IS '입항년도';

COMMENT ON COLUMN raw.mof_control_call.etrypt_co
IS '입항횟수';

COMMENT ON COLUMN raw.mof_control_call.clsgn
IS '선박 호출부호';

COMMENT ON COLUMN raw.mof_control_call.vssl_knd_cd
IS '선박종류코드';

COMMENT ON COLUMN raw.mof_control_call.vssl_knd_nm
IS '선박종류명';

COMMENT ON COLUMN raw.mof_control_call.vssl_nm
IS '선박명';

COMMENT ON COLUMN raw.mof_control_call.vssl_grtg
IS '선박 총톤수';

COMMENT ON COLUMN raw.mof_control_call.vssl_nlty_cd
IS '선박 국적코드';

COMMENT ON COLUMN raw.mof_control_call.vssl_nlty_nm
IS '선박 국적명';

COMMENT ON COLUMN raw.mof_control_call.vssl_satmnt_ag_cd
IS '선박 신고청코드';

COMMENT ON COLUMN raw.mof_control_call.satmnt_etrypt_year
IS '신고 입항년도';

COMMENT ON COLUMN raw.mof_control_call.satmnt_etrypt_co
IS '신고 입항횟수';

COMMENT ON COLUMN raw.mof_control_call.aprtf_etrypt_dt
IS '기항지 입항일시';

COMMENT ON COLUMN raw.mof_control_call.tkoff_dt
IS '출항일시';

COMMENT ON COLUMN raw.mof_control_call.harbor_entrps_cd
IS '항만업체코드';

COMMENT ON COLUMN raw.mof_control_call.harbor_entrps_nm
IS '항만업체명';

COMMENT ON COLUMN raw.mof_control_call.raw_payload
IS 'API에서 수집한 item 단위 원본 JSON 데이터';

COMMENT ON COLUMN raw.mof_control_call.first_inserted_at
IS '최초 데이터 적재일시';

COMMENT ON COLUMN raw.mof_control_call.updated_at
IS '최종 데이터 갱신일시';


-- ============================================================
-- raw.mof_control_event
-- ============================================================

COMMENT ON TABLE raw.mof_control_event
IS '해양수산부 선박 관제정보 API의 관제 이벤트(detail) 단위 원천 데이터';

COMMENT ON COLUMN raw.mof_control_event.control_event_raw_id
IS '관제 이벤트 원천 데이터 내부 식별자(PK)';

COMMENT ON COLUMN raw.mof_control_event.control_call_raw_id
IS '관제정보 부모 데이터 식별자(FK, raw.mof_control_call)';

COMMENT ON COLUMN raw.mof_control_event.cntrl_nm
IS '관제구분명(입항, 접안, 이안, 투묘, 양묘, 출항 등)';

COMMENT ON COLUMN raw.mof_control_event.etrypt_year
IS '관제 이벤트의 입항년도';

COMMENT ON COLUMN raw.mof_control_event.etrypt_co
IS '관제 이벤트의 입항횟수';

COMMENT ON COLUMN raw.mof_control_event.comm_co
IS '통신횟수(API 응답 내 관제 이벤트 순번)';

COMMENT ON COLUMN raw.mof_control_event.cntrl_se
IS '관제구분코드';

COMMENT ON COLUMN raw.mof_control_event.cntrl_opert_dt
IS '관제작업일시';

COMMENT ON COLUMN raw.mof_control_event.fclty_cd
IS '관제 이벤트 관련 항만시설코드';

COMMENT ON COLUMN raw.mof_control_event.fclty_sub_cd
IS '관제 이벤트 관련 항만시설 서브코드';

COMMENT ON COLUMN raw.mof_control_event.fclty_nm
IS '관제 이벤트 관련 항만시설명';

COMMENT ON COLUMN raw.mof_control_event.raw_payload
IS 'API에서 수집한 detail 단위 원본 JSON 데이터';

COMMENT ON COLUMN raw.mof_control_event.first_inserted_at
IS '최초 데이터 적재일시';

COMMENT ON COLUMN raw.mof_control_event.updated_at
IS '최종 데이터 갱신일시';