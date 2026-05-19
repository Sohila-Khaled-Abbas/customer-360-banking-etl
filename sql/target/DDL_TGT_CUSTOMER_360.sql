-- ============================================================
-- TARGET TABLE: TGT_CUSTOMER_360
-- Purpose : Golden Record — one consolidated row per customer
--           containing cleansed name, regional classification,
--           total share-of-wallet, and peak-spend quarter.
-- Load Mode: UPSERT (merge on CUST_ID)
-- ============================================================

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE TGT_CUSTOMER_360 CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE TGT_CUSTOMER_360 (
    CUST_ID             NUMBER          PRIMARY KEY,
    CUST_NAME_CLEAN     VARCHAR2(150)   NOT NULL,
    CUST_TYPE           VARCHAR2(20)    NOT NULL CHECK (CUST_TYPE IN ('VIP', 'NORMAL')),
    REGION              VARCHAR2(50)    NOT NULL,
    BLACKLIST_FLAG      VARCHAR2(1)     DEFAULT 'N' NOT NULL CHECK (BLACKLIST_FLAG IN ('Y', 'N')),

    -- Share of Wallet (ATM + Credit Card spend across all years)
    TOTAL_ATM_AMOUNT    NUMBER(15, 2)   DEFAULT 0,
    TOTAL_CC_SPEND      NUMBER(15, 2)   DEFAULT 0,
    TOTAL_WALLET        NUMBER(15, 2)   GENERATED ALWAYS AS (TOTAL_ATM_AMOUNT + TOTAL_CC_SPEND) VIRTUAL,

    -- Peak Quarter Analysis (derived from CC quarterly spend)
    Q1_SPEND_TOTAL      NUMBER(15, 2)   DEFAULT 0,
    Q2_SPEND_TOTAL      NUMBER(15, 2)   DEFAULT 0,
    Q3_SPEND_TOTAL      NUMBER(15, 2)   DEFAULT 0,
    Q4_SPEND_TOTAL      NUMBER(15, 2)   DEFAULT 0,
    PEAK_QUARTER        VARCHAR2(5),    -- e.g. 'Q1', 'Q2', 'Q3', 'Q4'

    -- Audit columns
    LOAD_TIMESTAMP      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    LAST_UPDATED        TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL
);

-- Index for common query patterns
CREATE INDEX IDX_C360_REGION      ON TGT_CUSTOMER_360 (REGION);
CREATE INDEX IDX_C360_CUST_TYPE   ON TGT_CUSTOMER_360 (CUST_TYPE);
CREATE INDEX IDX_C360_PEAK_QTR    ON TGT_CUSTOMER_360 (PEAK_QUARTER);

COMMENT ON TABLE  TGT_CUSTOMER_360                 IS 'Golden record table — one row per customer after full ETL cleansing and aggregation.';
COMMENT ON COLUMN TGT_CUSTOMER_360.CUST_NAME_CLEAN IS 'Name after LTRIM/RTRIM and non-alpha character removal via IICS Expression.';
COMMENT ON COLUMN TGT_CUSTOMER_360.TOTAL_WALLET    IS 'Virtual column: sum of all ATM and Credit Card spend.';
COMMENT ON COLUMN TGT_CUSTOMER_360.PEAK_QUARTER    IS 'Quarter label (Q1–Q4) with highest cumulative credit card spend.';
