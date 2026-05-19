# Mapplet: MPLT_Cleanse_Customer_Name

## Purpose
Reusable data cleansing mapplet that standardizes the `CUST_NAME` field by stripping
leading/trailing whitespace and removing non-alphabetic characters (excluding spaces).

---

## Transformation Design

| # | Transformation | Type | Details |
|---|----------------|------|---------|
| 1 | Input Group | Input | Port: `IN_CUST_NAME VARCHAR2(150)` |
| 2 | EXP_Cleanse_Name | Expression | See expression logic below |
| 3 | Output Group | Output | Port: `OUT_CUST_NAME VARCHAR2(150)` |

---

## Expression Logic (EXP_Cleanse_Name)

```
OUT_CUST_NAME = LTRIM(RTRIM(REG_REPLACE(IN_CUST_NAME, '[^a-zA-Z\s]', '')))
```

### Breakdown
| Function | Purpose |
|----------|---------|
| `REG_REPLACE(..., '[^a-zA-Z\s]', '')` | Remove any character that is NOT a letter or whitespace (strips symbols, digits, special chars) |
| `RTRIM(...)` | Remove trailing spaces |
| `LTRIM(...)` | Remove leading spaces |

---

## Test Cases

| Input `CUST_NAME` | Expected `OUT_CUST_NAME` |
|-------------------|--------------------------|
| `' rania hassan kamel'` | `'rania hassan kamel'` |
| `'Mona Abdelaziz Mahmoud  '` | `'Mona Abdelaziz Mahmoud'` |
| `'Sami Omar El-Fayed'` | `'Sami Omar ElFayed'` |
| `'Ahmed Ali #123'` | `'Ahmed Ali '` |

---

## Usage
Reference this mapplet in the main mapping `M_Customer_360_ETL` before the Router
transformation to ensure all customer name comparisons and golden record writes use
the cleansed value.
