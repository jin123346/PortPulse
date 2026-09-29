COMMENT ON SCHEMA raw IS
'외부 API 및 원천 시스템에서 수집한 데이터를 원본 형태에 가깝게 저장하는 영역. 
해양수산부 선박 입출항 정보, 관제정보 등 수집 데이터와 변경 이력 데이터를 보관한다.';

COMMENT ON SCHEMA master IS
'분석 및 통합 처리를 위한 기준정보 관리 영역. 
항만, 선박, 데이터 출처, 외부 시스템 코드 및 코드 간 매핑 정보를 관리한다.';

COMMENT ON SCHEMA fact IS
'원천 데이터를 정제·통합하여 분석 가능한 이벤트 및 사실 데이터를 저장하는 영역. 
선박 입출항, 관제 이벤트, 항만 이용 현황 등 분석의 중심이 되는 데이터를 관리한다.';

COMMENT ON SCHEMA mart IS
'대시보드 및 분석 서비스 제공을 위해 가공된 집계·분석 데이터를 저장하는 영역. 
항만별 입출항 현황, 혼잡도, 체류시간, 기간별 통계 등 조회 최적화 데이터를 관리한다.';

COMMENT ON TABLE raw.mof_ship_call IS
'해양수산부 선박 입출항 API에서 수집한 선박 입출항 건의 원천 데이터를 저장하는 테이블. 항만, 선박, 입항정보 및 이동 경로 정보를 저장하며 raw_payload에 API 원본 데이터를 JSONB 형태로 보관한다.';


COMMENT ON COLUMN raw.mof_ship_call.raw_id IS
'선박 입출항 원천 데이터 내부 식별자';

COMMENT ON COLUMN raw.mof_ship_call.request_id IS
'API 요청 단위를 식별하기 위한 요청 ID';

COMMENT ON COLUMN raw.mof_ship_call.prt_ag_cd IS
'항구청 코드(prtAgCd)';

COMMENT ON COLUMN raw.mof_ship_call.prt_ag_nm IS
'항구청 명칭(prtAgNm)';

COMMENT ON COLUMN raw.mof_ship_call.etrypt_yr IS
'입항 연도';

COMMENT ON COLUMN raw.mof_ship_call.etrypt_co IS
'입항 횟수';

COMMENT ON COLUMN raw.mof_ship_call.clsgn IS
'선박 호출부호';

COMMENT ON COLUMN raw.mof_ship_call.vssl_nm IS
'선박명';

COMMENT ON COLUMN raw.mof_ship_call.vssl_nlty_cd IS
'선박 국적 국가 코드';

COMMENT ON COLUMN raw.mof_ship_call.vssl_nlty_nm IS
'선박 국적 국가명';

COMMENT ON COLUMN raw.mof_ship_call.vssl_knd_cd IS
'선박 종류 코드';

COMMENT ON COLUMN raw.mof_ship_call.vssl_knd_nm IS
'선박 종류명';

COMMENT ON COLUMN raw.mof_ship_call.etrypt_purps_cd IS
'입항 목적 코드';

COMMENT ON COLUMN raw.mof_ship_call.etrypt_purps_nm IS
'입항 목적명';

COMMENT ON COLUMN raw.mof_ship_call.frst_dpmprt_nat_prt_cd IS
'최초 출항지 국가·항구 코드';

COMMENT ON COLUMN raw.mof_ship_call.frst_dpmprt_prt_nm IS
'최초 출항지 항구명';

COMMENT ON COLUMN raw.mof_ship_call.prvs_dpmprt_nat_prt_cd IS
'직전 출항지 국가·항구 코드';

COMMENT ON COLUMN raw.mof_ship_call.prvs_dpmprt_prt_nm IS
'직전 출항지 항구명';

COMMENT ON COLUMN raw.mof_ship_call.nxlnpt_nat_prt_cd IS
'차항지 국가·항구 코드';

COMMENT ON COLUMN raw.mof_ship_call.nxlnpt_prt_nm IS
'차항지 항구명';

COMMENT ON COLUMN raw.mof_ship_call.dstn_nat_prt_cd IS
'목적지 국가·항구 코드';

COMMENT ON COLUMN raw.mof_ship_call.dstn_prt_nm IS
'목적지 항구명';

COMMENT ON COLUMN raw.mof_ship_call.raw_payload IS
'해양수산부 API 응답의 해당 선박 입출항 원본 데이터를 JSONB 형태로 저장한 값';

COMMENT ON COLUMN raw.mof_ship_call.first_extracted_at IS
'해당 선박 입출항 건이 최초로 수집된 일시';

COMMENT ON COLUMN raw.mof_ship_call.update_extracted_at IS
'해당 선박 입출항 건이 마지막으로 갱신된 일시';


COMMENT ON TABLE raw.mof_ship_call_detail IS
'해양수산부 선박 입출항 API의 상세 입출항 정보를 저장하는 테이블. 선박 입출항 원천 데이터에 종속되며 입항·출항 구분, 계선시설, 화물, 선원, 신고업체 등의 상세 정보를 관리한다.';


COMMENT ON COLUMN raw.mof_ship_call_detail.detail_raw_id IS
'선박 입출항 상세 데이터 내부 식별자';

COMMENT ON COLUMN raw.mof_ship_call_detail.ship_call_raw_id IS
'상위 선박 입출항 원천 데이터 식별자(raw.mof_ship_call.raw_id)';

COMMENT ON COLUMN raw.mof_ship_call_detail.reqst_se_nm IS
'신청 구분명. 최초, 최종 등 API에서 제공되는 신청 상태 또는 구분값';

COMMENT ON COLUMN raw.mof_ship_call_detail.etrynd_nm IS
'입출항 구분명. 입항 또는 출항';

COMMENT ON COLUMN raw.mof_ship_call_detail.etrypt_dt IS
'입항 상세정보의 입항 일시';

COMMENT ON COLUMN raw.mof_ship_call_detail.tkoff_dt IS
'출항 상세정보의 출항 일시';

COMMENT ON COLUMN raw.mof_ship_call_detail.ibobprt_nm IS
'내항·외항 구분명';

COMMENT ON COLUMN raw.mof_ship_call_detail.laidup_fclty_cd IS
'계선시설 코드';

COMMENT ON COLUMN raw.mof_ship_call_detail.laidup_fclty_sub_cd IS
'계선시설 세부 코드';

COMMENT ON COLUMN raw.mof_ship_call_detail.laidup_fclty_nm IS
'계선시설 명칭';

COMMENT ON COLUMN raw.mof_ship_call_detail.tug_yn IS
'예선 사용 여부(Y/N)';

COMMENT ON COLUMN raw.mof_ship_call_detail.piltg_yn IS
'도선 사용 여부(Y/N)';

COMMENT ON COLUMN raw.mof_ship_call_detail.ldadng_frght_cl_cd IS
'적양하 화물 구분 또는 화물 명세 코드';

COMMENT ON COLUMN raw.mof_ship_call_detail.ldadng_ton IS
'적재 톤수';

COMMENT ON COLUMN raw.mof_ship_call_detail.trnpdt_ton IS
'환적 톤수';

COMMENT ON COLUMN raw.mof_ship_call_detail.landng_frght_ton IS
'양하 화물 톤수';

COMMENT ON COLUMN raw.mof_ship_call_detail.ld_frght_ton IS
'적재 화물 톤수';

COMMENT ON COLUMN raw.mof_ship_call_detail.grtg IS
'선박 총톤수';

COMMENT ON COLUMN raw.mof_ship_call_detail.intrl_grtg IS
'선박 국제 총톤수';

COMMENT ON COLUMN raw.mof_ship_call_detail.satmnt_entrps_nm IS
'입출항 신고 업체명';

COMMENT ON COLUMN raw.mof_ship_call_detail.crew_co IS
'전체 선원 수';

COMMENT ON COLUMN raw.mof_ship_call_detail.koran_crew_co IS
'한국인 선원 수';

COMMENT ON COLUMN raw.mof_ship_call_detail.frgnr_crew_co IS
'외국인 선원 수';

COMMENT ON COLUMN raw.mof_ship_call_detail.mr_num IS
'적하목록 관리번호';

COMMENT ON COLUMN raw.mof_ship_call_detail.tkoff_prrrn_dt IS
'출항 예정 일시';

COMMENT ON COLUMN raw.mof_ship_call_detail.dstn_etrypt_dt IS
'목적지 입항 예정 또는 입항 일시';

COMMENT ON COLUMN raw.mof_ship_call_detail.raw_payload IS
'해양수산부 API 응답의 해당 detail 원본 데이터를 JSONB 형태로 저장한 값';

COMMENT ON COLUMN raw.mof_ship_call_detail.first_created_at IS
'해당 상세 데이터가 최초로 저장된 일시';

COMMENT ON COLUMN raw.mof_ship_call_detail.updated_at IS
'해당 상세 데이터가 마지막으로 갱신된 일시';