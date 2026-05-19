# Connection Specs — IICS Cloud Data Integration

## Oracle Banking Database Connection

| Parameter | Value |
|-----------|-------|
| **Connection Name** | `CONN_Oracle_Banking_DB` |
| **Type** | Oracle |
| **Host** | `<your-oracle-host>` |
| **Port** | `1521` |
| **Service Name** | `<your-service-name>` |
| **Schema/Username** | `<your-schema>` |
| **Password** | Stored in IICS Secure Agent vault |
| **Tables used** | `SRC_BRANCHES`, `SRC_CUSTOMERS`, `SRC_ACCOUNTS` |
| **Target tables** | `TGT_CUSTOMER_360`, `TGT_EXCEPTION_LOG` |

---

## Flat File — ATM Transactions Connection

| Parameter | Value |
|-----------|-------|
| **Connection Name** | `CONN_FF_ATM_Transactions` |
| **Type** | Flat File |
| **File Path** | `/data/raw/atm_transactions/` |
| **File Pattern** | `ATM_Txn_*.csv` |
| **Delimiter** | `,` (comma) |
| **Header Row** | Yes (row 1) |
| **Date Format** | Mixed — `YYYY-MM-DD` and `DD/MM/YYYY` (requires Expression normalization) |
| **Null Representation** | Empty string (e.g., `AMOUNT` column may be blank) |

### ⚠️ Known Data Quality Issues
- `AMOUNT` field can be empty — handle with `IIF(ISNULL(AMOUNT) OR LENGTH(TRIM(AMOUNT)) = 0, 0, TO_DECIMAL(AMOUNT))`
- `TXN_DATE` has two date formats — normalize with: `IIF(INSTR(TXN_DATE,'-') > 0, TO_DATE(TXN_DATE,'YYYY-MM-DD'), TO_DATE(TXN_DATE,'DD/MM/YYYY'))`

---

## Flat File — Credit Card Spend Connection

| Parameter | Value |
|-----------|-------|
| **Connection Name** | `CONN_FF_CC_Spend` |
| **Type** | Flat File |
| **File Path** | `/data/raw/credit_card_spend/` |
| **File Pattern** | `CC_Spend_*.csv` |
| **Delimiter** | `,` (comma) |
| **Header Row** | Yes (row 1) |
| **Null Representation** | Empty `CUST_ID` field (signals `MISSING_PK` exception) |

### ⚠️ Known Data Quality Issues
- `CUST_ID` can be NULL → routed to `TGT_EXCEPTION_LOG` with reason `MISSING_PK`
- `CUST_ID = 999` is a ghost/orphan record not present in `SRC_CUSTOMERS` → will fail FK validation; log appropriately
