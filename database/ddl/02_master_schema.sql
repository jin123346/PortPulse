CREATE TABLE master.port_master (
    port_id BIGSERIAL PRIMARY KEY,
    port_name        VARCHAR(100) NOT NULL,
    management_type  VARCHAR(20),
    port_type        VARCHAR(20),
    managing_org     VARCHAR(100),
    location_text    VARCHAR(300),
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_port_master_name UNIQUE (port_name)
);


CREATE TABLE master.dim_mof_port_code (
    prt_ag_cd        VARCHAR(3) PRIMARY KEY,
    prt_ag_nm        VARCHAR(100) NOT NULL,
    region_name      VARCHAR(100),
    is_active        BOOLEAN DEFAULT TRUE,
    source_name      VARCHAR(100) DEFAULT 'MOF PORT-MIS API',
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE master.bridge_port_mof_code (
    port_id          BIGINT NOT NULL,
    prt_ag_cd        VARCHAR(3) NOT NULL,
    mapping_type     VARCHAR(30)
        CHECK (
            mapping_type IN (
                'EXACT',
                'SUB_PORT',
                'REGIONAL',
                'MANUAL'
            )
        ),

    note             VARCHAR(300),
    PRIMARY KEY (port_id, prt_ag_cd),
    FOREIGN KEY (port_id)
        REFERENCES master.port_master(port_id),
    FOREIGN KEY (prt_ag_cd)
        REFERENCES master.dim_mof_port_code(prt_ag_cd)
);



