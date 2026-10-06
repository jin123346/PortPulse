
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