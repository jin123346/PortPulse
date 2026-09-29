-- PortPulse master seed
-- Source: 해양수산부 항만정보 CSV + 확인한 MOF prtAgCd 목록
-- PostgreSQL
TRUNCATE TABLE master.port_master RESTART identity CASCADE;
-- ============================================================
-- 1) master.port_master : 해양수산부 항만정보 72건
-- ============================================================
INSERT INTO master.port_master
    (port_name, management_type, port_type, managing_org, location_text)
VALUES
    ('부산항', '국가관리', '무역항', '해양수산부 부산지방해양수산청', '부산광역시, 경상남도 창원시'),
    ('경인항', '국가관리', '무역항', '해양수산부 인천지방해양수산청', '인천광역시 서구 경서동 및 김포시 고촌읍'),
    ('인천항', '국가관리', '무역항', '해양수산부 인천지방해양수산청', '인천광역시 중구, 나구, 연수구 일원'),
    ('여수항', '국가관리', '무역항', '해양수산부 여수지방해양수산청', '전라남도 여수시'),
    ('마산항', '국가관리', '무역항', '해양수산부 마산지방해양수산청', '경상남도 창원시'),
    ('동해묵호항', '국가관리', '무역항', '해양수산부 동해지방해양수산청', '강원도 동해시'),
    ('군산항', '국가관리', '무역항', '해양수산부 군산지방해양수산청', '전라북도 군산시'),
    ('장항항', '국가관리', '무역항', '해양수산부 군산지방해양수산청', '충청남도 서천군 장항읍'),
    ('목포항', '국가관리', '무역항', '해양수산부 목포지방해양수산청', '전라남도 목포시, 영암군'),
    ('포항항', '국가관리', '무역항', '해양수산부 포항지방해양수산청', '경상북도 포항시'),
    ('울산항', '국가관리', '무역항', '해양수산부 울산지방해양수산청', '울산광역시'),
    ('대산항', '국가관리', '무역항', '해양수산부 대산지방해양수산청', '충청남도 서산시 대산읍'),
    ('용기포항', '국가관리', '연안항', '해양수산부 인천지방해양수산청', '인천광역시 옹진군 백령면 진촌리'),
    ('연평도항', '국가관리', '연안항', '해양수산부 인천지방해양수산청', '인천광역시 옹진군 연평면 연평리'),
    ('거문도항', '국가관리', '연안항', '해양수산부 여수지방해양수산청', '전라남도 여수시 삼산면 거문리, 덕촌리'),
    ('국도항', '국가관리', '연안항', '해양수산부 마산지방해양수산청', '경상남도 통영시 욕지면 동항리'),
    ('상왕등도항', '국가관리', '연안항', '해양수산부 군산지방해양수산청', '전라북도 부안군 위도면 상왕등리'),
    ('가거항리항', '국가관리', '연안항', '해양수산부 목포지방해양수산청', '전라남도 신안군 흑산면 항리'),
    ('흑산도항', '국가관리', '연안항', '해양수산부 목포지방해양수산청', '전라남도 신안군 흑산면 예리, 진리'),
    ('후포항', '국가관리', '연안항', '해양수산부 포항지방해양수산청', '경상북도 울진군 후포면 후포리'),
    ('울릉항', '국가관리', '연안항', '해양수산부 포항지방해양수산청', '경상북도 울릉군 울릉읍 도동리, 사동리'),
    ('추자항', '국가관리', '연안항', '제주특별자치도', '제주특별자치도 제주시 추자면'),
    ('화순항', '국가관리', '연안항', '제주특별자치도', '제주특별자치도 서귀포시 안덕면 화순리'),
    ('격렬비열도항', '국가관리', '연안항', '해양수산부 군산지방해양수산청', '충청남도 태안군 근흥면 가의도리'),
    ('부산항신항', '국가관리', '신항만', '해양수산부 부산지방해양수산청', '부산광역시 강서구 및 경상남도 창원시 진해구'),
    ('인천신항', '국가관리', '신항만', '해양수산부 인천지방해양수산청', '인천시 연수구 송도신도시 남측 및 서측해상'),
    ('인천북항', '국가관리', '신항만', '해양수산부 인천지방해양수산청', '인천광역시 동구 만석동 및 서구 원창동 일원의 해역'),
    ('광양항', '국가관리', '무역항', '해양수산부 여수지방해양수산청', '전라남도 광양시, 여수시, 순천시'),
    ('동해신항', '국가관리', '신항만', '해양수산부 동해지방해양수산청', '강원도 동해시 북평도 공유수면 일원'),
    ('새만금신항', '국가관리', '신항만', '해양수산부 군산지방해양수산청', '전라북도 군산시 옥도면 신시도리'),
    ('목포신항', '국가관리', '신항만', '해양수산부 목포지방해양수산청', '전남 목포시 허사도 및 장구도 일원'),
    ('영일만항', '국가관리', '신항만', '해양수산부 포항지방해양수산청', '경북 포항시 일원'),
    ('평택당진항', '국가관리', '무역항', '해양수산부 평택지방해양수산청', '경기도 화성시, 평택시 및 충남 당진시'),
    ('울산신항', '국가관리', '신항만', '해양수산부 울산지방해양수산청', '경남 울산시 용연동 및 울주군 일원'),
    ('보령신항', '국가관리', '신항만', '해양수산부 대산지방해양수산청', '충남 보령군 오천면 영보리 일원'),
    ('제주신항', '지방관리', '신항만', '제주특별자치도', '제주특별자치도 삼도동, 건입동, 용담동 공유수면 일원'),
    ('서울항', '지방관리', '무역항', '서울특별시', '서울특별시 영등포구 여의도동'),
    ('호산항', '지방관리', '무역항', '강원도', '강원도 삼척시 원덕읍 호산리'),
    ('삼척항', '지방관리', '무역항', '강원도', '강원도 삼척시'),
    ('옥계항', '지방관리', '무역항', '강원도', '강원도 강릉시 옥계면'),
    ('속초항', '지방관리', '무역항', '강원도', '강원도 속초시'),
    ('태안항', '지방관리', '무역항', '충청남도', '충남 태안군 태안읍'),
    ('보령항', '지방관리', '무역항', '충청남도', '충청남도 보령시 오천면'),
    ('완도항', '지방관리', '무역항', '전라남도', '전라남도 완도군 완도읍'),
    ('하동항', '지방관리', '무역항', '경상남도', '경상남도 하동군 금성면 갈사리'),
    ('삼천포항', '지방관리', '무역항', '경상남도', '경상남도 사천시, 고성군'),
    ('장승포항', '지방관리', '무역항', '경상남도', '경상남도 거제시'),
    ('옥포항', '지방관리', '무역항', '경상남도', '경상남도 거제시'),
    ('통영항', '지방관리', '무역항', '경상남도', '경상남도 통영시'),
    ('고현항', '지방관리', '무역항', '경상남도', '경상남도 거제시'),
    ('진해항', '지방관리', '무역항', '경상남도', '경상남도 창원시'),
    ('제주항', '지방관리', '무역항', '제주특별자치도', '제주특별자치도 제주시 건입동, 화북동'),
    ('서귀포항', '지방관리', '무역항', '제주특별자치도', '제주특별자치도 서귀포시'),
    ('부산남항', '지방관리', '연안항', '부산광역시', '부산광역시 중구 남포동, 서구 남부민동, 영도국 남항동 일원'),
    ('주문진항', '지방관리', '연안항', '강원도', '강원도 강릉시 주문진읍 주문리'),
    ('마량진항', '지방관리', '연안항', '충청남도', '충청남도 서천군 서면 미량리'),
    ('대천항', '지방관리', '연안항', '충청남도', '충청남도 보령시 신흑동'),
    ('진도항', '지방관리', '연안항', '전라남도', '전라남도 진도군  임회면 연동리'),
    ('땅끝항', '지방관리', '연안항', '전라남도', '전라남도 해남군 송지면 송호리'),
    ('녹동신항', '지방관리', '연안항', '전라남도', '전라남도 고흥군 도양읍 봉암리'),
    ('송공항', '지방관리', '연안항', '전라남도', '전라남도 신안군 입해읍 송공리'),
    ('화흥포항', '지방관리', '연안항', '전라남도', '전라남도 완도군'),
    ('홍도항', '지방관리', '연안항', '전라남도', '전남 신안군 흑산면 홍도리'),
    ('강진항', '지방관리', '연안항', '전라남도', '전라남도 강진군 마량면 마량리'),
    ('나로도항', '지방관리', '연안항', '전라남도', '전라남도 고흥군 봉래면 신금리'),
    ('구룡포항', '지방관리', '연안항', '경상북도', '경상북도 포항시 남구 구룡포읍'),
    ('강구항', '지방관리', '연안항', '경상북도', '경북 영덕군 강구면 강구리'),
    ('중화항', '지방관리', '연안항', '경상남도', '경상남도 통영시 산양읍 연화리'),
    ('한림항', '지방관리', '연안항', '제주특별자치도', '제주특별자치도 제주시 한립읍 대림리, 한수리'),
    ('애월항', '지방관리', '연안항', '제주특별자치도', '제주특별자치도 제주시 애월읍 애월리'),
    ('성산포항', '지방관리', '연안항', '제주특별자치도', '제주특별자치도 서귀포시 성산읍 성산리, 오조리'),
    ('진촌항', '지방관리', '연안항', '경상남도', '경상남도 통영시 사량면 금평리')
ON CONFLICT (port_name) DO UPDATE
SET management_type = EXCLUDED.management_type,
    port_type       = EXCLUDED.port_type,
    managing_org    = EXCLUDED.managing_org,
    location_text   = EXCLUDED.location_text,
    updated_at      = CURRENT_TIMESTAMP;

-- ============================================================
-- 2) master.mof_port_code : MOF/PORT-MIS prtAgCd
-- ※ '소속 항만'으로 적힌 명칭은 실제 항만명 확인 전 임시 설명값
-- ============================================================
INSERT INTO master.dim_mof_port_code
    (prt_ag_cd, prt_ag_nm, region_name)
VALUES
    ('020', '부산', '부산'),
    ('030', '인천', '인천'),
    ('031', '평택·당진', '평택'),
    ('090', '불개항청', '기타'),
    ('200', '동해', '동해'),
    ('201', '동해권 소속 항만', '동해권'),
    ('202', '묵호', '동해권'),
    ('203', '동해권 소속 항만', '동해권'),
    ('204', '동해권 소속 항만', '동해권'),
    ('300', '대산', '대산'),
    ('301', '보령', '대산권'),
    ('302', '태안', '대산권'),
    ('303', '대산권 소속 항만', '대산권'),
    ('304', '대산권 소속 항만', '대산권'),
    ('500', '군산', '군산'),
    ('501', '군산권 소속 항만', '군산권'),
    ('610', '목포', '목포'),
    ('616', '목포권 소속 항만', '목포권'),
    ('617', '목포권 소속 항만', '목포권'),
    ('620', '여수', '여수'),
    ('621', '여천', '여수'),
    ('622', '광양', '여수'),
    ('700', '포항', '포항'),
    ('701', '포항권 소속 항만', '포항권'),
    ('702', '포항권 소속 항만', '포항권'),
    ('810', '마산', '마산'),
    ('811', '마산권 소속 항만', '마산권'),
    ('812', '마산권 소속 항만', '마산권'),
    ('813', '장승포', '거제'),
    ('814', '마산권 소속 항만', '마산권'),
    ('816', '마산권 소속 항만', '마산권'),
    ('817', '여수권 소속 항만', '여수권'),
    ('820', '울산', '울산'),
    ('821', '울산권 소속 항만', '울산권'),
    ('822', '울산권 소속 항만', '울산권'),
    ('900', '제주', '제주'),
    ('901', '제주권 소속 항만', '제주권')
ON CONFLICT (prt_ag_cd) DO UPDATE
SET prt_ag_nm   = EXCLUDED.prt_ag_nm,
    region_name = EXCLUDED.region_name,
    updated_at  = CURRENT_TIMESTAMP;

-- ============================================================
-- 3) master.port_code_mapping : 확인 가능한 매핑만 우선 등록
-- port_id를 하드코딩하지 않고 port_name으로 찾아서 INSERT
-- ============================================================
INSERT INTO master.bridge_port_mof_code 
    (port_id, prt_ag_cd, mapping_type, note)
SELECT
    p.port_id,
    '020',
    'EXACT',
    'MOF API 부산 코드'
FROM master.port_master p
WHERE p.port_name = '부산항'
ON CONFLICT (port_id, prt_ag_cd) DO UPDATE
SET mapping_type = EXCLUDED.mapping_type,
    note         = EXCLUDED.note;

INSERT INTO master.bridge_port_mof_code
    (port_id, prt_ag_cd, mapping_type, note)
SELECT
    p.port_id,
    '030',
    'EXACT',
    'MOF API 인천 코드'
FROM master.port_master p
WHERE p.port_name = '인천항'
ON CONFLICT (port_id, prt_ag_cd) DO UPDATE
SET mapping_type = EXCLUDED.mapping_type,
    note         = EXCLUDED.note;

INSERT INTO master.bridge_port_mof_code
    (port_id, prt_ag_cd, mapping_type, note)
SELECT
    p.port_id,
    '031',
    'EXACT',
    'MOF API 평택·당진 코드'
FROM master.port_master p
WHERE p.port_name = '평택당진항'
ON CONFLICT (port_id, prt_ag_cd) DO UPDATE
SET mapping_type = EXCLUDED.mapping_type,
    note         = EXCLUDED.note;

INSERT INTO master.bridge_port_mof_code
    (port_id, prt_ag_cd, mapping_type, note)
SELECT
    p.port_id,
    '200',
    'SUB_PORT',
    '동해묵호항 중 동해 코드'
FROM master.port_master p
WHERE p.port_name = '동해묵호항'
ON CONFLICT (port_id, prt_ag_cd) DO UPDATE
SET mapping_type = EXCLUDED.mapping_type,
    note         = EXCLUDED.note;

INSERT INTO master.bridge_port_mof_code
    (port_id, prt_ag_cd, mapping_type, note)
SELECT
    p.port_id,
    '202',
    'SUB_PORT',
    '동해묵호항 중 묵호 코드'
FROM master.port_master p
WHERE p.port_name = '동해묵호항'
ON CONFLICT (port_id, prt_ag_cd) DO UPDATE
SET mapping_type = EXCLUDED.mapping_type,
    note         = EXCLUDED.note;

INSERT INTO master.bridge_port_mof_code
    (port_id, prt_ag_cd, mapping_type, note)
SELECT
    p.port_id,
    '300',
    'EXACT',
    'MOF API 대산 코드'
FROM master.port_master p
WHERE p.port_name = '대산항'
ON CONFLICT (port_id, prt_ag_cd) DO UPDATE
SET mapping_type = EXCLUDED.mapping_type,
    note         = EXCLUDED.note;

INSERT INTO master.bridge_port_mof_code
    (port_id, prt_ag_cd, mapping_type, note)
SELECT
    p.port_id,
    '301',
    'EXACT',
    'MOF API 보령 코드'
FROM master.port_master p
WHERE p.port_name = '보령항'
ON CONFLICT (port_id, prt_ag_cd) DO UPDATE
SET mapping_type = EXCLUDED.mapping_type,
    note         = EXCLUDED.note;

INSERT INTO master.bridge_port_mof_code
    (port_id, prt_ag_cd, mapping_type, note)
SELECT
    p.port_id,
    '302',
    'EXACT',
    'MOF API 태안 코드'
FROM master.port_master p
WHERE p.port_name = '태안항'
ON CONFLICT (port_id, prt_ag_cd) DO UPDATE
SET mapping_type = EXCLUDED.mapping_type,
    note         = EXCLUDED.note;

INSERT INTO master.bridge_port_mof_code
    (port_id, prt_ag_cd, mapping_type, note)
SELECT
    p.port_id,
    '500',
    'EXACT',
    'MOF API 군산 코드'
FROM master.port_master p
WHERE p.port_name = '군산항'
ON CONFLICT (port_id, prt_ag_cd) DO UPDATE
SET mapping_type = EXCLUDED.mapping_type,
    note         = EXCLUDED.note;

INSERT INTO master.bridge_port_mof_code
    (port_id, prt_ag_cd, mapping_type, note)
SELECT
    p.port_id,
    '610',
    'EXACT',
    'MOF API 목포 코드'
FROM master.port_master p
WHERE p.port_name = '목포항'
ON CONFLICT (port_id, prt_ag_cd) DO UPDATE
SET mapping_type = EXCLUDED.mapping_type,
    note         = EXCLUDED.note;

INSERT INTO master.bridge_port_mof_code
    (port_id, prt_ag_cd, mapping_type, note)
SELECT
    p.port_id,
    '620',
    'EXACT',
    'MOF API 여수 코드'
FROM master.port_master p
WHERE p.port_name = '여수항'
ON CONFLICT (port_id, prt_ag_cd) DO UPDATE
SET mapping_type = EXCLUDED.mapping_type,
    note         = EXCLUDED.note;

INSERT INTO master.bridge_port_mof_code
    (port_id, prt_ag_cd, mapping_type, note)
SELECT
    p.port_id,
    '622',
    'EXACT',
    'MOF API 광양 코드'
FROM master.port_master p
WHERE p.port_name = '광양항'
ON CONFLICT (port_id, prt_ag_cd) DO UPDATE
SET mapping_type = EXCLUDED.mapping_type,
    note         = EXCLUDED.note;

INSERT INTO master.bridge_port_mof_code
    (port_id, prt_ag_cd, mapping_type, note)
SELECT
    p.port_id,
    '700',
    'EXACT',
    'MOF API 포항 코드'
FROM master.port_master p
WHERE p.port_name = '포항항'
ON CONFLICT (port_id, prt_ag_cd) DO UPDATE
SET mapping_type = EXCLUDED.mapping_type,
    note         = EXCLUDED.note;

INSERT INTO master.bridge_port_mof_code
    (port_id, prt_ag_cd, mapping_type, note)
SELECT
    p.port_id,
    '810',
    'EXACT',
    'MOF API 마산 코드'
FROM master.port_master p
WHERE p.port_name = '마산항'
ON CONFLICT (port_id, prt_ag_cd) DO UPDATE
SET mapping_type = EXCLUDED.mapping_type,
    note         = EXCLUDED.note;

INSERT INTO master.bridge_port_mof_code
    (port_id, prt_ag_cd, mapping_type, note)
SELECT
    p.port_id,
    '813',
    'EXACT',
    'MOF API 장승포 코드'
FROM master.port_master p
WHERE p.port_name = '장승포항'
ON CONFLICT (port_id, prt_ag_cd) DO UPDATE
SET mapping_type = EXCLUDED.mapping_type,
    note         = EXCLUDED.note;

INSERT INTO master.bridge_port_mof_code
    (port_id, prt_ag_cd, mapping_type, note)
SELECT
    p.port_id,
    '820',
    'EXACT',
    'MOF API 울산 코드'
FROM master.port_master p
WHERE p.port_name = '울산항'
ON CONFLICT (port_id, prt_ag_cd) DO UPDATE
SET mapping_type = EXCLUDED.mapping_type,
    note         = EXCLUDED.note;

INSERT INTO master.bridge_port_mof_code
    (port_id, prt_ag_cd, mapping_type, note)
SELECT
    p.port_id,
    '900',
    'EXACT',
    'MOF API 제주 코드'
FROM master.port_master p
WHERE p.port_name = '제주항'
ON CONFLICT (port_id, prt_ag_cd) DO UPDATE
SET mapping_type = EXCLUDED.mapping_type,
    note         = EXCLUDED.note;



-- 확인용
SELECT
    p.port_id,
    p.port_name,
    m.prt_ag_cd,
    c.prt_ag_nm,
    m.mapping_type,
    m.note
FROM master.bridge_port_mof_code m
JOIN master.port_master p
  ON p.port_id = m.port_id
JOIN master.dim_mof_port_code c
  ON c.prt_ag_cd = m.prt_ag_cd
ORDER BY p.port_name, m.prt_ag_cd;