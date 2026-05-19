-- ============================================================
-- TARGET TABLE: TGT_EXCEPTION_LOG
-- Purpose : Audit / quarantine log for all records rejected
--           by the Router Transformation exception matrix.
-- Load Mode: INSERT ONLY (append — never delete history)
-- ============================================================

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE TGT_EXCEPTION_LOG CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE TGT_EXCEPTION_LOG (
    LOG_ID              NUMBER          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    -- Source identifiers (nullable — PK may be missing)
    CUST_ID             NUMBER,
    CARD_NO             VARCHAR2(20),
    ACC_ID              NUMBER,
    TXN_ID              VARCHAR2(20),

    -- Rejection classification
    EXCEPTION_REASON    VARCHAR2(50)    NOT NULL
        CHECK (EXCEPTION_REASON IN (
            'MISSING_PK',               -- Rule 1: NULL CUST_ID in card files
            'SUSPENDED_ACCOUNT_TXN',    -- Rule 3: ACC_STATUS=SUSPENDED or BLACKLIST_FLAG=Y
            'DEBIT_LIMIT_EXCEEDED'      -- Rule 2: NORMAL customer with >1 debit card
        )),

    -- Raw field snapshot for forensic review
    RAW_CUST_ID         VARCHAR2(50),   -- Original value before type conversion
    RAW_ACC_STATUS      VARCHAR2(20),
    RAW_BLACKLIST_FLAG  VARCHAR2(1),
    RAW_CUST_TYPE       VARCHAR2(20),
    RAW_DEBIT_CARD_COUNT NUMBER,

    -- Source traceability
    SOURCE_FILE         VARCHAR2(100),  -- e.g. 'CC_Spend_2023.csv', 'ATM_Txn_Cairo.csv'
    MAPPING_NAME        VARCHAR2(100),  -- IICS mapping that generated this record

    -- Audit
    LOAD_TIMESTAMP      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL
);

-- Indexes for exception reporting queries
CREATE INDEX IDX_EXC_REASON       ON TGT_EXCEPTION_LOG (EXCEPTION_REASON);
CREATE INDEX IDX_EXC_CUST_ID      ON TGT_EXCEPTION_LOG (CUST_ID);
CREATE INDEX IDX_EXC_LOAD_TS      ON TGT_EXCEPTION_LOG (LOAD_TIMESTAMP);

COMMENT ON TABLE  TGT_EXCEPTION_LOG                    IS 'Append-only audit log for all records rejected by the ETL exception matrix.';
COMMENT ON COLUMN TGT_EXCEPTION_LOG.EXCEPTION_REASON   IS 'Controlled vocabulary: MISSING_PK | SUSPENDED_ACCOUNT_TXN | DEBIT_LIMIT_EXCEEDED.';
COMMENT ON COLUMN TGT_EXCEPTION_LOG.SOURCE_FILE        IS 'Name of the flat file or Oracle source table that originated this rejected record.';
