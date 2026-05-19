# 🏦 Customer 360 — Banking ETL Pipeline
### *Informatica Cloud Data Integration (IICS) | Oracle → Data Warehouse*

> **Diploma Capstone Project — Data Engineering Diploma @ Data Pill**  
> A multi-source ETL pipeline that consolidates banking, ATM, and credit card data into a single **Customer 360 golden record**, enforcing a strict exception matrix to quarantine non-conforming records.

---

## 📌 Business Objective

A regional bank operates across **four governorates** (Cairo, Alexandria, Giza, Delta, Upper Egypt) with data scattered across:

- An **Oracle transactional database** (`SRC_BRANCHES`, `SRC_CUSTOMERS`, `SRC_ACCOUNTS`)
- **ATM transaction CSV files** split by city and refreshed daily
- **Credit Card spend CSV files** split by year with quarterly breakdowns

The ETL pipeline must:

1. **Cleanse** customer names (strip illegal characters & extra whitespace)
2. **Enforce** three data quality exception rules, routing bad records to an audit log
3. **Aggregate** a per-customer *Share of Wallet* (ATM + CC spend)
4. **Identify** the *Peak Spending Quarter* (Q1–Q4) per customer for marketing targeting
5. **Upsert** golden records to `TGT_CUSTOMER_360` without overwriting historical data

---

## 🗂️ Repository Structure

```
customer-360-banking-etl/
│
├── 📁 data/
│   └── raw/
│       ├── atm_transactions/          # ATM CSV files (Alexandria, Cairo, Giza)
│       │   ├── ATM_Txn_Alex.csv
│       │   ├── ATM_Txn_Cairo.csv
│       │   └── ATM_Txn_Giza.csv
│       └── credit_card_spend/         # CC spend CSVs (2023–2025)
│           ├── CC_Spend_2023.csv
│           ├── CC_Spend_2024.csv
│           └── CC_Spend_2025.csv
│
├── 📁 sql/
│   ├── source/
│   │   └── oracle_banking_db.sql      # Source DDL + seed data (branches, customers, accounts)
│   └── target/
│       ├── DDL_TGT_CUSTOMER_360.sql   # Golden record target table
│       └── DDL_TGT_EXCEPTION_LOG.sql  # Audit/quarantine log table
│
├── 📁 iics/
│   ├── connections/
│   │   └── Connection_Specs.md        # Oracle & Flat File connection parameters
│   ├── mapplets/
│   │   └── MPLT_Cleanse_Customer_Name.md  # Reusable name-cleansing mapplet spec
│   └── mappings/
│       └── M_Customer_360_ETL.md      # Full 6-phase mapping design specification
│
├── 📁 docs/
│   ├── Business_Requirements_Document.pdf
│   └── Data_Dictionary.pdf
│
├── .gitignore
├── CHANGELOG.md
└── README.md                          # ← You are here
```

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────┐
│         SOURCE LAYER                │
│  Oracle DB          Flat Files      │
│  ├─ SRC_BRANCHES    ├─ ATM_Alex     │
│  ├─ SRC_CUSTOMERS   ├─ ATM_Cairo    │
│  └─ SRC_ACCOUNTS    ├─ ATM_Giza    │
│                     ├─ CC_2023      │
│                     ├─ CC_2024      │
│                     └─ CC_2025      │
└────────────────┬────────────────────┘
                 │  IICS CDI Mapping
                 ▼
┌─────────────────────────────────────┐
│    INTEGRATION & CLEANSING LAYER    │
│  ┌──────────────┐                   │
│  │ JNR: Accounts│  JNR: Customers   │
│  │ + Branches   │──► (main join)    │
│  └──────────────┘                   │
│  MPLT_Cleanse_Customer_Name         │
│  AGG: Debit Card Count per CUST_ID  │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│       EXCEPTION MATRIX (Router)     │
│  ┌──────────────────────────────┐   │
│  │ Rule 1: MISSING_PK           │──►│─► TGT_EXCEPTION_LOG
│  │ Rule 2: DEBIT_LIMIT_EXCEEDED │──►│─► TGT_EXCEPTION_LOG
│  │ Rule 3: SUSPENDED_ACCOUNT    │──►│─► TGT_EXCEPTION_LOG
│  │ Default: CLEAN records       │   │
│  └──────────────────────────────┘   │
└────────────────┬────────────────────┘
                 │ Clean records only
                 ▼
┌─────────────────────────────────────┐
│     GOLDEN RECORD AGGREGATION       │
│  AGG: Group by CUST_ID              │
│    ├─ SUM(ATM AMOUNT)               │
│    ├─ SUM(Q1..Q4 CC spend)          │
│    └─ TOTAL_WALLET                  │
│  EXP: Peak Quarter Detection        │
│    └─ DECODE → 'Q1'|'Q2'|'Q3'|'Q4' │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│         TARGET LAYER                │
│  TGT_CUSTOMER_360  (UPSERT)         │
└─────────────────────────────────────┘
```

---

## ⚡ Exception Matrix

| Rule | Condition | Exception Reason | Target |
|------|-----------|-----------------|--------|
| **Rule 1** | `CUST_ID IS NULL` in CC/ATM files | `MISSING_PK` | `TGT_EXCEPTION_LOG` |
| **Rule 2** | `CUST_TYPE = 'NORMAL'` AND `DEBIT_CARD_COUNT > 1` | `DEBIT_LIMIT_EXCEEDED` | `TGT_EXCEPTION_LOG` |
| **Rule 3** | `ACC_STATUS = 'SUSPENDED'` OR `BLACKLIST_FLAG = 'Y'` | `SUSPENDED_ACCOUNT_TXN` | `TGT_EXCEPTION_LOG` |

> **Rule 2 Design Note:** Debit card violations cannot be detected row-by-row.  
> An **Aggregator** groups by `CUST_ID` to count debit cards first, then that count is joined back to the pipeline before the Router evaluates the condition.

---

## 🔑 Key IICS Expressions

### Name Cleansing (Mapplet)
```
OUT_CUST_NAME = LTRIM(RTRIM(REG_REPLACE(CUST_NAME, '[^a-zA-Z\s]', '')))
```

### ATM Date Normalization (Expression)
```
NORM_DATE = IIF(INSTR(TXN_DATE,'-') > 0,
              TO_DATE(TXN_DATE, 'YYYY-MM-DD'),
              TO_DATE(TXN_DATE, 'DD/MM/YYYY'))
```

### Peak Quarter Detection (Two-Pass DECODE)
```sql
-- Pass 1: find the numeric maximum
$$MAX_SPEND = DECODE(TRUE,
  Q1 >= Q2 AND Q1 >= Q3 AND Q1 >= Q4, Q1,
  Q2 >= Q3 AND Q2 >= Q4,              Q2,
  Q3 >= Q4,                           Q3,
  Q4)

-- Pass 2: map the max value back to a string label
PEAK_QUARTER = DECODE($$MAX_SPEND, Q1,'Q1', Q2,'Q2', Q3,'Q3', 'Q4')
```

---

## 🛠️ Quick Start

### Prerequisites
- Oracle Database (19c+) or compatible
- Informatica Intelligent Cloud Services (IICS) tenant with Cloud Data Integration
- IICS Secure Agent with network access to the Oracle host

### Step 1 — Set Up Source Schema
```sql
-- Run in your Oracle instance
@sql/source/oracle_banking_db.sql
```

### Step 2 — Set Up Target Schema
```sql
-- Run in your Oracle target instance (can be same DB, different schema)
@sql/target/DDL_TGT_CUSTOMER_360.sql
@sql/target/DDL_TGT_EXCEPTION_LOG.sql
```

### Step 3 — Configure IICS Connections
Follow the specs in [`iics/connections/Connection_Specs.md`](iics/connections/Connection_Specs.md) to register:
- `CONN_Oracle_Banking_DB`
- `CONN_FF_ATM_Transactions`
- `CONN_FF_CC_Spend`

### Step 4 — Build IICS Assets
| Order | Asset | Spec |
|-------|-------|------|
| 1 | Mapplet | [`MPLT_Cleanse_Customer_Name.md`](iics/mapplets/MPLT_Cleanse_Customer_Name.md) |
| 2 | Mapping | [`M_Customer_360_ETL.md`](iics/mappings/M_Customer_360_ETL.md) |
| 3 | Task | Create a Mapping Task wrapping `M_Customer_360_ETL` |

---

## 📊 Source Data Summary

| File | Records | Notes |
|------|---------|-------|
| `oracle_banking_db.sql` | 4 branches, 15 customers, 22 accounts | Includes suspended accounts & blacklisted customer |
| `ATM_Txn_Cairo.csv` | 65 transactions | Contains 2 NULL AMOUNT rows |
| `ATM_Txn_Alex.csv` | 55 transactions | Mixed date formats |
| `ATM_Txn_Giza.csv` | 60 transactions | Contains 1 NULL AMOUNT row |
| `CC_Spend_2023.csv` | 11 cards | CARD_50009 has NULL CUST_ID; CARD_50010 has ghost CUST_ID=999 |
| `CC_Spend_2024.csv` | 13 cards | CARD_60011 has NULL CUST_ID; CARD_60012 has ghost CUST_ID=999 |
| `CC_Spend_2025.csv` | 12 cards | CARD_70010 has NULL CUST_ID; CARD_70011 has ghost CUST_ID=999 |

---

## 📄 Documentation

| Document | Location |
|----------|----------|
| Business Requirements | [`docs/Business_Requirements_Document.pdf`](docs/Business_Requirements_Document.pdf) |
| Data Dictionary | [`docs/Data_Dictionary.pdf`](docs/Data_Dictionary.pdf) |
| Mapping Blueprint | [`iics/mappings/M_Customer_360_ETL.md`](iics/mappings/M_Customer_360_ETL.md) |
| Mapplet Spec | [`iics/mapplets/MPLT_Cleanse_Customer_Name.md`](iics/mapplets/MPLT_Cleanse_Customer_Name.md) |
| Connection Specs | [`iics/connections/Connection_Specs.md`](iics/connections/Connection_Specs.md) |
| Changelog | [`CHANGELOG.md`](CHANGELOG.md) |

---

## 🎓 Academic Context

| Field | Detail |
|-------|--------|
| **Program** | Data Engineering Diploma |
| **Institute** | Data Pill |
| **Topic** | ETL Development with Informatica Cloud Data Integration |
| **Concepts covered** | Multi-source integration, Router transformation, Aggregator transformation, Mapplets, Upsert strategy, Data quality exception handling |

---

## 📜 License

This project is for **educational purposes only**. All data is synthetic and does not represent real banking customers or transactions.
