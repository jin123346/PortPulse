/* =====================================================================
   master.dim_mof_vessel_kind : 선박 종류 코드 및 관제 대상 여부

   control_expected        : 관제 대상 선종인가 (false면 미매칭이 정상)
   control_exempt_domestic : 내항(ibobprt_nm = '내항')이면 관제 비대상인가

   판단 근거 (2026-10-05 fact_ship_call 미매칭 분석)
   - 부선(71~77, 79): 예선이 끌고 다니므로 관제 기록이 예선 쪽에 남음.
                      72·76·77·79는 미매칭 100% 확인, 71·74는 같은 부선이라 동일 처리
   - 유람선(97): 전국 미매칭 100%
   - 여객선(11): 외항(부산)은 전부 매칭, 내항(제주·목포)은 관제 기록 없음
   - 신조선(78)은 7x 번호대지만 부선이 아니므로 관제 대상으로 둠
   - 수상레저기구(89), 기타선(99) 등 근거가 부족한 코드는 기본값(대상)
   ===================================================================== */

CREATE TABLE IF NOT EXISTS master.dim_mof_vessel_kind (
    vssl_knd_cd             varchar(20)  PRIMARY KEY,
    vssl_knd_nm             varchar(100) NOT NULL,
    control_expected        boolean      NOT NULL DEFAULT true,
    control_exempt_domestic boolean      NOT NULL DEFAULT false,
    note                    varchar(500),
    created_at              timestamp    DEFAULT CURRENT_TIMESTAMP,
    updated_at              timestamp    DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE  master.dim_mof_vessel_kind                         IS '선박 종류 코드 및 관제 대상 여부';
COMMENT ON COLUMN master.dim_mof_vessel_kind.vssl_knd_cd             IS '선박 종류 코드 (raw.mof_ship_call.vssl_knd_cd)';
COMMENT ON COLUMN master.dim_mof_vessel_kind.vssl_knd_nm             IS '선박 종류명';
COMMENT ON COLUMN master.dim_mof_vessel_kind.control_expected        IS '관제 대상 선종 여부. false면 관제 미매칭이 정상';
COMMENT ON COLUMN master.dim_mof_vessel_kind.control_exempt_domestic IS '내항 입항이면 관제 비대상 여부';
COMMENT ON COLUMN master.dim_mof_vessel_kind.note                    IS '판단 근거';


INSERT INTO master.dim_mof_vessel_kind
    (vssl_knd_cd, vssl_knd_nm, control_expected, control_exempt_domestic, note)
VALUES
    -- 여객
    ('11', '여객선',               true,  true,  '외항은 관제 매칭, 내항 정기 여객선은 관제 기록 없음 (제주·목포 확인)'),
    ('13', '국제카페리',           true,  false, NULL),
    ('14', '크루즈선',             true,  false, NULL),
    -- 화물
    ('21', '산물선(벌크선)',       true,  false, NULL),
    ('24', '광석운반선',           true,  false, NULL),
    ('25', '석탄운반선',           true,  false, NULL),
    ('26', '시멘트운반선',         true,  false, NULL),
    ('27', '자동차운반선',         true,  false, NULL),
    ('28', '핫코일운반선',         true,  false, NULL),
    ('29', '철강재 운반선',        true,  false, NULL),
    ('30', '코일전용선',           true,  false, NULL),
    ('31', '모래운반선',           true,  false, NULL),
    ('32', '냉동.냉장선',          true,  false, NULL),
    ('33', '폐기물 운반선',        true,  false, NULL),
    ('39', '일반화물선',           true,  false, NULL),
    -- 컨테이너
    ('41', '풀컨테이너선',         true,  false, NULL),
    ('42', '세미(혼재)컨테이너선', true,  false, NULL),
    -- 유조·가스
    ('51', '원유운반선',           true,  false, NULL),
    ('52', '석유제품 운반선',      true,  false, NULL),
    ('53', '케미칼 운반선',        true,  false, NULL),
    ('54', '케미칼가스 운반선',    true,  false, NULL),
    ('55', 'LPG 운반선',           true,  false, NULL),
    ('56', 'LNG 운반선',           true,  false, NULL),
    ('59', '기타 유조선',          true,  false, NULL),
    -- 예선
    ('61', '견인용예선',           true,  false, NULL),
    ('62', '이.접안용 예선',       true,  false, NULL),
    ('63', '압항 예선',            true,  false, NULL),
    ('69', '기타 예선',            true,  false, NULL),
    -- 부선 (78 신조선은 부선 아님)
    ('71', '모래운반용 부선',      false, false, '부선: 예선이 끄는 배라 관제 기록은 예선 쪽에 남음'),
    ('72', '철강재운반용 부선',    false, false, '부선: 예선이 끄는 배라 관제 기록은 예선 쪽에 남음 (미매칭 100%)'),
    ('74', '석유제품운반용 부선',  false, false, '부선: 예선이 끄는 배라 관제 기록은 예선 쪽에 남음'),
    ('76', '일반화물운반용 부선',  false, false, '부선: 예선이 끄는 배라 관제 기록은 예선 쪽에 남음 (미매칭 100%)'),
    ('77', '공사(작업)용 부선',    false, false, '부선: 예선이 끄는 배라 관제 기록은 예선 쪽에 남음 (미매칭 100%)'),
    ('78', '신조선',               true,  false, '7x 번호대지만 부선 아님'),
    ('79', '기타 부선',            false, false, '부선: 예선이 끄는 배라 관제 기록은 예선 쪽에 남음 (미매칭 100%)'),
    -- 기타
    ('81', '관공선',               true,  false, NULL),
    ('89', '수상레저기구',         true,  false, '판단 보류: 미매칭 비율 확인 필요'),
    ('92', '원양 어선',            true,  false, NULL),
    ('93', '급유선',               true,  false, NULL),
    ('95', '용달선',               true,  false, NULL),
    ('96', '준설선',               true,  false, NULL),
    ('97', '유람선',               false, false, '전국 미매칭 100%'),
    ('99', '기타선',               true,  false, '판단 보류: 전국 미매칭 31%, 제주는 100%'),
    ('12', '화객선',               true,  false, '2026-10 신규. 매칭 추이 보고 여객선처럼 내항 비대상 여부 판단'),
    ('64', '통선',                 true,  false, '2026-10 신규. 소형 항내선이라 관제 비대상일 수 있음, 매칭 추이 보고 판단')
ON CONFLICT (vssl_knd_cd) DO UPDATE SET
    vssl_knd_nm             = EXCLUDED.vssl_knd_nm,
    control_expected        = EXCLUDED.control_expected,
    control_exempt_domestic = EXCLUDED.control_exempt_domestic,
    note                    = EXCLUDED.note,
    updated_at              = CURRENT_TIMESTAMP;



ALTER TABLE master.dim_mof_vessel_kind
    ADD COLUMN IF NOT EXISTS raw_vssl_knd_nm varchar(100);
COMMENT ON COLUMN master.dim_mof_vessel_kind.raw_vssl_knd_nm IS
    '원천(raw)에 최근 들어온 선종명. 자동 갱신. vssl_knd_nm과 다르면 확인 필요';

UPDATE master.dim_mof_vessel_kind vk
SET raw_vssl_knd_nm = r.raw_name
FROM (SELECT vssl_knd_cd, MAX(vssl_knd_nm) AS raw_name
      FROM raw.mof_ship_call GROUP BY 1) r
WHERE r.vssl_knd_cd = vk.vssl_knd_cd;


INSERT INTO master.dim_mof_vessel_kind
       (vssl_knd_cd, vssl_knd_nm, raw_vssl_knd_nm, control_expected, control_exempt_domestic, note)
SELECT msc.vssl_knd_cd,
       COALESCE(MAX(msc.vssl_knd_nm), '미상'),
       MAX(msc.vssl_knd_nm),
       true, false,
       '자동 추가: 관제 대상 여부 판단 필요'
FROM raw.mof_ship_call msc
WHERE msc.vssl_knd_cd IS NOT NULL
GROUP BY msc.vssl_knd_cd
ON CONFLICT (vssl_knd_cd) DO UPDATE SET
    raw_vssl_knd_nm = EXCLUDED.raw_vssl_knd_nm,
    updated_at      = CURRENT_TIMESTAMP
WHERE master.dim_mof_vessel_kind.raw_vssl_knd_nm IS DISTINCT FROM EXCLUDED.raw_vssl_knd_nm
RETURNING vssl_knd_cd, vssl_knd_nm, raw_vssl_knd_nm, (xmax = 0) AS is_new;


/* 확인 1: raw에 있는데 이 테이블에 없는 코드 (0건이어야 함) */
SELECT msc.vssl_knd_cd, MAX(msc.vssl_knd_nm) AS vssl_knd_nm, COUNT(*) AS ship_calls
FROM raw.mof_ship_call msc
LEFT JOIN master.dim_mof_vessel_kind vk ON vk.vssl_knd_cd = msc.vssl_knd_cd
WHERE msc.vssl_knd_cd IS NOT NULL
  AND vk.vssl_knd_cd IS NULL
GROUP BY msc.vssl_knd_cd;

/* 확인 2: 관제 비대상 규칙 적용 시 미매칭 구분 */
SELECT
    CASE
        WHEN NOT COALESCE(vk.control_expected, true)                                  THEN '관제 비대상 선종'
        WHEN COALESCE(vk.control_exempt_domestic, false) AND f.ibobprt_nm = '내항'     THEN '내항 비대상 (여객선)'
        ELSE '관제 대상'
    END AS grp,
    COUNT(*) AS total,
    COUNT(*) FILTER (WHERE f.control_call_raw_id IS NULL) AS unmatched
FROM fact.fact_ship_call f
JOIN raw.mof_ship_call msc ON msc.raw_id = f.ship_call_raw_id
LEFT JOIN master.dim_mof_vessel_kind vk ON vk.vssl_knd_cd = msc.vssl_knd_cd
GROUP BY 1
ORDER BY 1;


