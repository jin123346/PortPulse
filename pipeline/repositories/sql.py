MOF_SHIP_CALL_INSERT_SQL="""
                        INSERT INTO raw.mof_ship_call
                        (
                        request_id, 
                        prt_ag_cd, 
                        prt_ag_nm, 
                        etrypt_yr, 
                        etrypt_co, 
                        clsgn, 
                        vssl_nm, 
                        vssl_nlty_cd, 
                        vssl_nlty_nm, 
                        vssl_knd_cd, 
                        vssl_knd_nm, 
                        etrypt_purps_cd, 
                        etrypt_purps_nm, 
                        frst_dpmprt_nat_prt_cd, 
                        frst_dpmprt_prt_nm, 
                        prvs_dpmprt_nat_prt_cd, 
                        prvs_dpmprt_prt_nm, 
                        nxlnpt_nat_prt_cd, 
                        nxlnpt_prt_nm, 
                        dstn_nat_prt_cd, 
                        dstn_prt_nm, 
                        raw_payload, 
                        extracted_at
                    )
                    VALUES(
                    nextval(
                    %s, %s, %s, %s, 
                    %s, %s, %s, %s, 
                    %s, %s, %s, %s, 
                    %s, %s, %s, %s, 
                    %s, %s, %s, %s, 
                    %s, %s, %s);
"""