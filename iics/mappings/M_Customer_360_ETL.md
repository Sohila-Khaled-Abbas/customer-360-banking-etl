# Mapping: M_Customer_360_ETL

## Overview
Single unified IICS Cloud Data Integration (CDI) mapping that ingests all source systems,
applies the exception matrix, aggregates golden records, and upserts to target tables.

---

## Transformation Canvas (Left → Right)

```
[SRC_BRANCHES]  ──┐
                   ├──► JNR_Accounts_Branches ──┐
[SRC_ACCOUNTS]  ──┘                              ├──► JNR_Main ──► MPLT_Cleanse_Name ──► AGG_Debit_Count ──► JNR_Count_Back ──► RTR_Exception_Matrix
[SRC_CUSTOMERS] ──────────────────────────────── ┘
[ATM CSVs x3]   ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────── ┘
[CC CSVs x3]    ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────── ┘
```

---

## Phase 1 — Sources

| Source | Connection Type | Object | Key Ports |
|--------|----------------|--------|-----------|
| `SRC_BRANCHES` | Oracle | `SRC_BRANCHES` table | `BRANCH_ID`, `REGION` |
| `SRC_CUSTOMERS` | Oracle | `SRC_CUSTOMERS` table | `CUST_ID`, `CUST_NAME`, `CUST_TYPE`, `BLACKLIST_FLAG` |
| `SRC_ACCOUNTS` | Oracle | `SRC_ACCOUNTS` table | `ACC_ID`, `CUST_ID`, `BRANCH_ID`, `ACC_STATUS` |
| `ATM_Txn_Alex` | Flat File (CSV) | `ATM_Txn_Alex.csv` | `TXN_ID`, `ACC_ID`, `TXN_DATE`, `AMOUNT` |
| `ATM_Txn_Cairo` | Flat File (CSV) | `ATM_Txn_Cairo.csv` | `TXN_ID`, `ACC_ID`, `TXN_DATE`, `AMOUNT` |
| `ATM_Txn_Giza` | Flat File (CSV) | `ATM_Txn_Giza.csv` | `TXN_ID`, `ACC_ID`, `TXN_DATE`, `AMOUNT` |
| `CC_Spend_2023` | Flat File (CSV) | `CC_Spend_2023.csv` | `CARD_NO`, `CUST_ID`, `Q1_SPEND`–`Q4_SPEND` |
| `CC_Spend_2024` | Flat File (CSV) | `CC_Spend_2024.csv` | `CARD_NO`, `CUST_ID`, `Q1_SPEND`–`Q4_SPEND` |
| `CC_Spend_2025` | Flat File (CSV) | `CC_Spend_2025.csv` | `CARD_NO`, `CUST_ID`, `Q1_SPEND`–`Q4_SPEND` |

---

## Phase 2 — Joiner Transformations

### JNR_Accounts_Branches
- **Type:** Joiner
- **Master:** `SRC_BRANCHES`
- **Detail:** `SRC_ACCOUNTS`
- **Condition:** `SRC_ACCOUNTS.BRANCH_ID = SRC_BRANCHES.BRANCH_ID`
- **Output ports added:** `REGION`, `ACC_STATUS`

### JNR_Main
- **Type:** Joiner
- **Master:** `SRC_CUSTOMERS`
- **Detail:** Output of `JNR_Accounts_Branches`
- **Condition:** `SRC_CUSTOMERS.CUST_ID = JNR_Accounts_Branches.CUST_ID`
- **Output ports added:** `CUST_NAME`, `CUST_TYPE`, `BLACKLIST_FLAG`

---

## Phase 3 — Debit Card Count (Pre-Router Aggregation)

### AGG_Debit_Count
- **Type:** Aggregator
- **Group By:** `CUST_ID`
- **Aggregate Port:**  
  ```
  DEBIT_CARD_COUNT = COUNT( IIF(CARD_TYPE = 'DEBIT', 1, NULL) )
  ```

### JNR_Count_Back
- **Type:** Joiner — joins `DEBIT_CARD_COUNT` back to the main pipeline on `CUST_ID`

---

## Phase 4 — Router Transformation (RTR_Exception_Matrix)

| Group | Condition | Target | Exception Reason Literal |
|-------|-----------|--------|--------------------------|
| `GRP_Missing_PK` | `ISNULL(CUST_ID)` | `TGT_EXCEPTION_LOG` | `'MISSING_PK'` |
| `GRP_Suspended` | `ACC_STATUS = 'SUSPENDED' OR BLACKLIST_FLAG = 'Y'` | `TGT_EXCEPTION_LOG` | `'SUSPENDED_ACCOUNT_TXN'` |
| `GRP_Debit_Limit` | `CUST_TYPE = 'NORMAL' AND DEBIT_CARD_COUNT > 1` | `TGT_EXCEPTION_LOG` | `'DEBIT_LIMIT_EXCEEDED'` |
| `Default` | (all remaining clean records) | → Phase 5 aggregation | — |

---

## Phase 5 — Golden Record Aggregation (Clean Path)

### AGG_Golden_Record
- **Type:** Aggregator
- **Group By:** `CUST_ID`
- **Output Ports:**

| Port | Expression |
|------|-----------|
| `TOTAL_ATM_AMOUNT` | `SUM(ATM_AMOUNT)` |
| `Q1_SPEND_TOTAL` | `SUM(Q1_SPEND)` |
| `Q2_SPEND_TOTAL` | `SUM(Q2_SPEND)` |
| `Q3_SPEND_TOTAL` | `SUM(Q3_SPEND)` |
| `Q4_SPEND_TOTAL` | `SUM(Q4_SPEND)` |
| `TOTAL_CC_SPEND` | `SUM(Q1_SPEND + Q2_SPEND + Q3_SPEND + Q4_SPEND)` |

### EXP_Peak_Quarter
- **Type:** Expression
- **Logic (Variable ports — evaluated top to bottom):**

```
$$MAX_SPEND  = DECODE(TRUE,
                 Q1_SPEND_TOTAL >= Q2_SPEND_TOTAL AND Q1_SPEND_TOTAL >= Q3_SPEND_TOTAL AND Q1_SPEND_TOTAL >= Q4_SPEND_TOTAL, Q1_SPEND_TOTAL,
                 Q2_SPEND_TOTAL >= Q3_SPEND_TOTAL AND Q2_SPEND_TOTAL >= Q4_SPEND_TOTAL, Q2_SPEND_TOTAL,
                 Q3_SPEND_TOTAL >= Q4_SPEND_TOTAL, Q3_SPEND_TOTAL,
                 Q4_SPEND_TOTAL)

PEAK_QUARTER = DECODE($$MAX_SPEND,
                 Q1_SPEND_TOTAL, 'Q1',
                 Q2_SPEND_TOTAL, 'Q2',
                 Q3_SPEND_TOTAL, 'Q3',
                 'Q4')
```

> **Design Decision:** Using a two-pass DECODE (first find the numeric max, then map the max value
> back to its string label) is the idiomatic IICS pattern for returning a column *name* as a string.
> This solves the challenge of dynamically identifying which quarterly port holds the peak value.

---

## Phase 6 — Target Writes

| Target Transformation | Table | Operation |
|-----------------------|-------|-----------|
| `TGT_CUSTOMER_360` | `TGT_CUSTOMER_360` | **Upsert** (Update-else-Insert) on `CUST_ID` |
| `TGT_EXCEPTION_LOG` | `TGT_EXCEPTION_LOG` | **Insert** only |
