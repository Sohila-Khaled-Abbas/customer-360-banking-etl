<div align="center">

# 🏦 Customer 360 — Banking ETL Pipeline

**Informatica Cloud Data Integration (IICS) &nbsp;|&nbsp; Oracle → Data Warehouse**

[![Platform](https://img.shields.io/badge/Platform-Informatica%20IICS-FF6D00?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0id2hpdGUiIGQ9Ik0xMiAyQzYuNDggMiAyIDYuNDggMiAxMnM0LjQ4IDEwIDEwIDEwIDEwLTQuNDggMTAtMTBTMTcuNTIgMiAxMiAyem0tMiAxNWwtNS01IDEuNDEtMS40MUwxMCAxNC4xN2w3LjU5LTcuNTkgMS40MSAxLjQxTDEwIDE3eiIvPjwvc3ZnPg==&logoColor=white)](https://www.informatica.com/products/cloud-data-integration.html)
[![Database](https://img.shields.io/badge/Source-Oracle%20DB-F80000?style=for-the-badge&logo=oracle&logoColor=white)](https://www.oracle.com/database/)
[![Data Format](https://img.shields.io/badge/Files-CSV%20Flat%20Files-217346?style=for-the-badge&logo=microsoftexcel&logoColor=white)](data/raw/)
[![Pattern](https://img.shields.io/badge/Pattern-ETL%20Pipeline-4285F4?style=for-the-badge&logo=googlecloud&logoColor=white)]()
[![Status](https://img.shields.io/badge/Status-Completed-2ea44f?style=for-the-badge)]()
[![Academic](https://img.shields.io/badge/Type-Diploma%20Capstone-8A2BE2?style=for-the-badge&logo=academia&logoColor=white)]()

---

*A production-grade multi-source ETL pipeline that consolidates banking, ATM, and credit card data  
into a single **Customer 360 golden record**, enforcing a strict three-rule exception matrix  
to quarantine non-conforming records before they reach the data warehouse.*

</div>

---

## 📋 Table of Contents

- [Business Objective](#-business-objective)
- [Architecture Overview](#️-architecture-overview)
- [Repository Structure](#️-repository-structure)
- [Pipeline Phases](#-pipeline-phases)
- [Exception Matrix](#-exception-matrix)
- [Key IICS Expressions](#-key-iics-expressions)
- [Source Data Inventory](#-source-data-inventory)
- [Quick Start](#️-quick-start)
- [Documentation](#-documentation)
- [Academic Context](#-academic-context)

---

## 📌 Business Objective

A regional Egyptian bank operates across **five governorates** with transactional data siloed across three distinct systems:

| System | Format | Contents |
|--------|--------|----------|
| Oracle Banking DB | Relational Tables | Branches, Customers, Accounts |
| ATM Network | CSV — per city | Daily cash withdrawal transactions |
| Credit Card Platform | CSV — per year | Quarterly card spend by customer |

**The pipeline must deliver:**

- ✅ **Name Cleansing** — strip illegal characters & normalize whitespace from `CUST_NAME`
- ✅ **Exception Enforcement** — three data quality rules with quarantine routing
- ✅ **Share of Wallet** — per-customer aggregation of ATM + CC spend
- ✅ **Peak Quarter Detection** — identify Q1/Q2/Q3/Q4 with highest spend for marketing
- ✅ **Safe Upsert** — update existing customers or insert new ones without data loss

---

## 🏗️ Architecture Overview

```
╔══════════════════════════════════════════════════════════════╗
║                      SOURCE LAYER                           ║
║                                                              ║
║   ┌─── Oracle DB ───┐        ┌──── Flat Files (CSV) ──────┐  ║
║   │ SRC_BRANCHES    │        │ ATM_Txn_Alex.csv           │  ║
║   │ SRC_CUSTOMERS   │        │ ATM_Txn_Cairo.csv          │  ║
║   │ SRC_ACCOUNTS    │        │ ATM_Txn_Giza.csv           │  ║
║   └────────┬────────┘        │ CC_Spend_2023/24/25.csv    │  ║
║            │                 └──────────────┬─────────────┘  ║
╚════════════╪═════════════════════════════════╪══════════════╝
             │         IICS CDI Mapping        │
             └─────────────────┬───────────────┘
                               ▼
╔══════════════════════════════════════════════════════════════╗
║              INTEGRATION & CLEANSING LAYER                  ║
║                                                              ║
║   JNR: Accounts ⋈ Branches  →  JNR: + Customers            ║
║   MPLT_Cleanse_Customer_Name  (regex name sanitization)     ║
║   AGG: Count DEBIT cards per CUST_ID                        ║
║   JNR: Rejoin debit count to main pipeline                  ║
╚══════════════════════════════════════════════════════════════╝
                               │
                               ▼
╔══════════════════════════════════════════════════════════════╗
║               EXCEPTION MATRIX  (Router)                    ║
║                                                              ║
║   ┌─ Group 1: ISNULL(CUST_ID)                    ──────────►║─► TGT_EXCEPTION_LOG  'MISSING_PK'
║   ├─ Group 2: ACC_STATUS='SUSPENDED' OR BL='Y'   ──────────►║─► TGT_EXCEPTION_LOG  'SUSPENDED_ACCOUNT_TXN'
║   ├─ Group 3: NORMAL cust AND DEBIT_COUNT > 1    ──────────►║─► TGT_EXCEPTION_LOG  'DEBIT_LIMIT_EXCEEDED'
║   └─ Default: All clean records                  ──────────►║─► Next stage ✔
╚══════════════════════════════════════════════════════════════╝
                               │ clean records only
                               ▼
╔══════════════════════════════════════════════════════════════╗
║             GOLDEN RECORD AGGREGATION                       ║
║                                                              ║
║   AGG (Group by CUST_ID):                                   ║
║     • SUM(ATM AMOUNT)  →  TOTAL_ATM_AMOUNT                  ║
║     • SUM(Q1..Q4)      →  Q*_SPEND_TOTAL + TOTAL_CC_SPEND   ║
║   EXP: Two-pass DECODE  →  PEAK_QUARTER ('Q1'|'Q2'|...)     ║
╚══════════════════════════════════════════════════════════════╝
                               │
                               ▼
╔══════════════════════════════════════════════════════════════╗
║                      TARGET LAYER                           ║
║                                                              ║
║   TGT_CUSTOMER_360   ← UPSERT on CUST_ID                    ║
╚══════════════════════════════════════════════════════════════╝
```

---

## 🗂️ Repository Structure

```
customer-360-banking-etl/
│
├── 📁 data/
│   └── raw/
│       ├── atm_transactions/           ← ATM CSV files per city
│       │   ├── ATM_Txn_Alex.csv
│       │   ├── ATM_Txn_Cairo.csv
│       │   └── ATM_Txn_Giza.csv
│       └── credit_card_spend/          ← CC spend per year (Q1–Q4 breakdown)
│           ├── CC_Spend_2023.csv
│           ├── CC_Spend_2024.csv
│           └── CC_Spend_2025.csv
│
├── 📁 sql/
│   ├── source/
│   │   └── oracle_banking_db.sql       ← Source DDL + seed data
│   └── target/
│       ├── DDL_TGT_CUSTOMER_360.sql    ← Golden record target table (upsert)
│       └── DDL_TGT_EXCEPTION_LOG.sql   ← Append-only audit/quarantine log
│
├── 📁 iics/
│   ├── connections/
│   │   └── Connection_Specs.md         ← Oracle & Flat File connection parameters
│   ├── mapplets/
│   │   └── MPLT_Cleanse_Customer_Name.md  ← Reusable name-cleansing mapplet spec
│   └── mappings/
│       └── M_Customer_360_ETL.md       ← Full 6-phase mapping blueprint
│
├── 📁 docs/
│   ├── Business_Requirements_Document.pdf
│   └── Data_Dictionary.pdf
│
├── .gitignore
├── CHANGELOG.md
└── README.md
```

---

## 🔄 Pipeline Phases

<details>
<summary><strong>Phase 1 — Connection & Mapplet Architecture</strong></summary>

### Connections Required

| Connection Name | Type | Serves |
|----------------|------|--------|
| `CONN_Oracle_Banking_DB` | Oracle | `SRC_*` source tables + `TGT_*` target tables |
| `CONN_FF_ATM_Transactions` | Flat File | `ATM_Txn_*.csv` (pattern-matched) |
| `CONN_FF_CC_Spend` | Flat File | `CC_Spend_*.csv` (pattern-matched) |

### MPLT_Cleanse_Customer_Name

A reusable **Mapplet** containing a single Expression transformation:

```
OUT_CUST_NAME = LTRIM(RTRIM(REG_REPLACE(CUST_NAME, '[^a-zA-Z\s]', '')))
```

| Input | Output |
|-------|--------|
| `' rania hassan kamel'` | `'rania hassan kamel'` |
| `'Mona Abdelaziz Mahmoud  '` | `'Mona Abdelaziz Mahmoud'` |
| `'Sami Omar El-Fayed'` | `'Sami Omar ElFayed'` |

</details>

<details>
<summary><strong>Phase 2 — Staging & Integration</strong></summary>

### Joiner Chain

```
SRC_ACCOUNTS  ──┐
                 ├── JNR_Accounts_Branches ──┐
SRC_BRANCHES  ──┘    (on BRANCH_ID)          │
                                              ├── JNR_Main ──► unified stream
SRC_CUSTOMERS ────────────────────────────────┘  (on CUST_ID)
```

All flat file sources (ATM x3, CC x3) are unioned into the pipeline alongside the Oracle streams before the join chain.

</details>

<details>
<summary><strong>Phase 3 — Exception Matrix (Router)</strong></summary>

> **Rule 2 Design Note:** A debit card limit violation cannot be detected row-by-row.  
> An **Aggregator** must first group by `CUST_ID` to count DEBIT cards, and that count is joined back before the Router evaluates `DEBIT_CARD_COUNT > 1`.

| Group | Condition | Hardcoded Reason | Target |
|-------|-----------|-----------------|--------|
| `GRP_Missing_PK` | `ISNULL(CUST_ID)` | `'MISSING_PK'` | `TGT_EXCEPTION_LOG` |
| `GRP_Suspended` | `ACC_STATUS='SUSPENDED'` OR `BLACKLIST_FLAG='Y'` | `'SUSPENDED_ACCOUNT_TXN'` | `TGT_EXCEPTION_LOG` |
| `GRP_Debit_Limit` | `CUST_TYPE='NORMAL' AND DEBIT_CARD_COUNT > 1` | `'DEBIT_LIMIT_EXCEEDED'` | `TGT_EXCEPTION_LOG` |
| `Default` | *(all remaining)* | — | Phase 4 → |

</details>

<details>
<summary><strong>Phase 4 — Golden Record Aggregation</strong></summary>

### AGG_Golden_Record — Group By `CUST_ID`

| Output Port | Expression |
|-------------|-----------|
| `TOTAL_ATM_AMOUNT` | `SUM(ATM_AMOUNT)` |
| `Q1_SPEND_TOTAL` | `SUM(Q1_SPEND)` |
| `Q2_SPEND_TOTAL` | `SUM(Q2_SPEND)` |
| `Q3_SPEND_TOTAL` | `SUM(Q3_SPEND)` |
| `Q4_SPEND_TOTAL` | `SUM(Q4_SPEND)` |
| `TOTAL_CC_SPEND` | `SUM(Q1_SPEND + Q2_SPEND + Q3_SPEND + Q4_SPEND)` |

### EXP_Peak_Quarter — Two-Pass DECODE

```sql
-- Variable port: find the numeric peak
$$MAX_SPEND = DECODE(TRUE,
  Q1 >= Q2 AND Q1 >= Q3 AND Q1 >= Q4, Q1,
  Q2 >= Q3 AND Q2 >= Q4,              Q2,
  Q3 >= Q4,                           Q3,
  Q4)

-- Output port: resolve the numeric peak to a string label
PEAK_QUARTER = DECODE($$MAX_SPEND, Q1,'Q1', Q2,'Q2', Q3,'Q3', 'Q4')
```

> **Why two passes?** IICS expressions cannot reference a column *name* as a string output directly.  
> The two-pass pattern first isolates the numeric maximum, then uses that value as a lookup key  
> to return the corresponding quarter *label* — the idiomatic IICS solution to this class of problem.

</details>

<details>
<summary><strong>Phase 5 — Upsert to Target</strong></summary>

| Setting | Value |
|---------|-------|
| Target Table | `TGT_CUSTOMER_360` |
| Operation | **Upsert** (Update-else-Insert) |
| Match Key | `CUST_ID` |
| Rationale | Preserves existing customer history while accommodating new enrollments |

The exception log target (`TGT_EXCEPTION_LOG`) is set to **Insert Only** — records are never updated or deleted to maintain a complete audit trail.

</details>

---

## ⚡ Exception Matrix

| Rule | Icon | Condition | Exception Code | Destination |
|------|------|-----------|---------------|-------------|
| **Rule 1** | 🔑 | `CUST_ID IS NULL` in any source file | `MISSING_PK` | `TGT_EXCEPTION_LOG` |
| **Rule 2** | 💳 | `CUST_TYPE = 'NORMAL'` AND `DEBIT_CARD_COUNT > 1` | `DEBIT_LIMIT_EXCEEDED` | `TGT_EXCEPTION_LOG` |
| **Rule 3** | 🚫 | `ACC_STATUS = 'SUSPENDED'` OR `BLACKLIST_FLAG = 'Y'` | `SUSPENDED_ACCOUNT_TXN` | `TGT_EXCEPTION_LOG` |

> [!WARNING]
> Rule 2 requires a **pre-Router Aggregator** step. Evaluating this condition directly in the Router against raw rows will produce incorrect results because the debit card count is a cross-row aggregation, not a per-row attribute.

---

## 🔑 Key IICS Expressions

### 🧹 Name Cleansing — `MPLT_Cleanse_Customer_Name`

```
OUT_CUST_NAME = LTRIM(RTRIM(REG_REPLACE(CUST_NAME, '[^a-zA-Z\s]', '')))
```

### 📅 ATM Date Normalization — Mixed Format Handler

```
NORM_DATE = IIF(INSTR(TXN_DATE, '-') > 0,
              TO_DATE(TXN_DATE, 'YYYY-MM-DD'),
              TO_DATE(TXN_DATE, 'DD/MM/YYYY'))
```

> [!NOTE]
> ATM files contain two date formats (`2025-07-03` and `03/07/2025`) within the same column.  
> The `INSTR` check detects the format by looking for a hyphen, then routes to the appropriate `TO_DATE` conversion.

### 💰 Null Amount Guard — Safe Numeric Cast

```
SAFE_AMOUNT = IIF(ISNULL(AMOUNT) OR LENGTH(TRIM(TO_CHAR(AMOUNT))) = 0, 0, TO_DECIMAL(AMOUNT))
```

### 🏆 Peak Quarter Detection — Two-Pass DECODE

```sql
-- Pass 1 (Variable port $$): numeric maximum
$$MAX_SPEND = DECODE(TRUE,
  Q1 >= Q2 AND Q1 >= Q3 AND Q1 >= Q4, Q1,
  Q2 >= Q3 AND Q2 >= Q4,              Q2,
  Q3 >= Q4,                           Q3,
  Q4)

-- Pass 2 (Output port): string label
PEAK_QUARTER = DECODE($$MAX_SPEND, Q1,'Q1', Q2,'Q2', Q3,'Q3', 'Q4')
```

---

## 📊 Source Data Inventory

### Oracle Banking Database

| Table | Rows | Key Details |
|-------|------|-------------|
| `SRC_BRANCHES` | 4 | Regions: CAIRO, ALEX, DELTA, UPPER_EGYPT |
| `SRC_CUSTOMERS` | 15 | Includes 1 blacklisted (`CUST_ID=104`), 1 name with leading space (`105`), 1 with trailing spaces (`102`) |
| `SRC_ACCOUNTS` | 22 | 2 accounts are SUSPENDED (CUST_ID=104) |

### ATM Transaction Files

| File | Transactions | Known Issues |
|------|-------------|--------------|
| `ATM_Txn_Cairo.csv` | 65 | 2 rows with NULL `AMOUNT` (TXN_1006, TXN_1027) |
| `ATM_Txn_Alex.csv` | 55 | Mixed date formats throughout |
| `ATM_Txn_Giza.csv` | 60 | 1 row with NULL `AMOUNT` (TXN_3048) |

### Credit Card Spend Files

| File | Cards | Anomalies |
|------|-------|-----------|
| `CC_Spend_2023.csv` | 11 | `CARD_50009` → NULL CUST_ID &nbsp;&#124;&nbsp; `CARD_50010` → Ghost CUST_ID=999 |
| `CC_Spend_2024.csv` | 13 | `CARD_60011` → NULL CUST_ID &nbsp;&#124;&nbsp; `CARD_60012` → Ghost CUST_ID=999 |
| `CC_Spend_2025.csv` | 12 | `CARD_70010` → NULL CUST_ID &nbsp;&#124;&nbsp; `CARD_70011` → Ghost CUST_ID=999 |

> [!IMPORTANT]
> `CUST_ID = 999` is a **ghost record** — it appears in all three CC spend files but has no corresponding row in `SRC_CUSTOMERS`. These records will pass the `MISSING_PK` rule (CUST_ID is not null) but will fail a referential integrity check at load time. Consider adding a **Lookup transformation** against `SRC_CUSTOMERS` to catch orphaned foreign keys.

---

## 🛠️ Quick Start

> [!NOTE]
> You must execute the **target DDL scripts before** building any IICS mappings.  
> IICS cannot configure a Target transformation without the endpoint tables existing in the database.

### Prerequisites

| Requirement | Version |
|-------------|---------|
| Oracle Database | 19c+ (or compatible) |
| Informatica IICS Tenant | CDI license required |
| IICS Secure Agent | Must have network reach to Oracle host |

### Step 1 — Provision Source Schema

```sql
-- Run against your Oracle source instance
@sql/source/oracle_banking_db.sql
```

### Step 2 — Provision Target Schema

```sql
-- Run against your Oracle target instance (may be same DB, different schema)
@sql/target/DDL_TGT_CUSTOMER_360.sql
@sql/target/DDL_TGT_EXCEPTION_LOG.sql
```

### Step 3 — Configure IICS Connections

Register three connections in IICS → **Administrator → Connections**:

```
CONN_Oracle_Banking_DB    (Oracle)
CONN_FF_ATM_Transactions  (Flat File → data/raw/atm_transactions/)
CONN_FF_CC_Spend          (Flat File → data/raw/credit_card_spend/)
```

Full parameter reference: [`iics/connections/Connection_Specs.md`](iics/connections/Connection_Specs.md)

### Step 4 — Build IICS Assets (in order)

```
1. 📦  Mapplet   →  MPLT_Cleanse_Customer_Name    (iics/mapplets/)
2. 🗺️  Mapping   →  M_Customer_360_ETL            (iics/mappings/)
3. ▶️  Task      →  Mapping Task wrapping M_Customer_360_ETL
```

---

## 📄 Documentation

| Document | Description | Link |
|----------|-------------|------|
| 📋 Business Requirements | Functional specs, exception rules, acceptance criteria | [BRD.pdf](docs/Business_Requirements_Document.pdf) |
| 📖 Data Dictionary | Column-level definitions for all source and target tables | [Data_Dictionary.pdf](docs/Data_Dictionary.pdf) |
| 🗺️ Mapping Blueprint | Full 6-phase IICS mapping technical specification | [M_Customer_360_ETL.md](iics/mappings/M_Customer_360_ETL.md) |
| 📦 Mapplet Spec | Expression logic, test cases for name cleansing mapplet | [MPLT_Cleanse_Customer_Name.md](iics/mapplets/MPLT_Cleanse_Customer_Name.md) |
| 🔌 Connection Specs | IICS connection parameters + data quality notes | [Connection_Specs.md](iics/connections/Connection_Specs.md) |
| 📝 Changelog | Version history in Keep-a-Changelog format | [CHANGELOG.md](CHANGELOG.md) |

---

## 🎓 Academic Context

<div align="center">

| | |
|---|---|
| 🏫 **Institute** | Data Pill |
| 📚 **Program** | Data Engineering Diploma |
| 🧪 **Project Type** | Capstone — End-to-End ETL Implementation |
| 🛠️ **Primary Tool** | Informatica Intelligent Cloud Services (IICS) — Cloud Data Integration |
| 🧠 **Concepts Covered** | Multi-source integration · Router transformation · Aggregator transformation · Mapplets · Upsert strategy · Data quality exception handling · Peak quarter analytics |

</div>

---

## 📜 License

> This project is developed for **educational purposes only**.  
> All data is entirely synthetic and does not represent real banking customers, accounts, or transactions.

---

<div align="center">

Made with ❤️ as part of the **Data Engineering Diploma** at **Data Pill**

[![Oracle](https://img.shields.io/badge/Oracle-F80000?style=flat-square&logo=oracle&logoColor=white)](https://www.oracle.com/)
[![Informatica](https://img.shields.io/badge/Informatica-FF6D00?style=flat-square&logoColor=white)](https://www.informatica.com/)
[![CSV](https://img.shields.io/badge/CSV-Flat%20Files-217346?style=flat-square&logo=microsoftexcel&logoColor=white)]()
[![ETL](https://img.shields.io/badge/ETL-Pipeline-4285F4?style=flat-square&logo=googlecloud&logoColor=white)]()

</div>
