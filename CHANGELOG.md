# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

### Planned
- IICS task flow for end-to-end orchestration
- Data quality dashboard (row counts, exception rates per run)
- Parameterized run dates for incremental loads

---

## [1.0.0] — 2026-05-19

### Added
- Oracle source DDL (`oracle_banking_db.sql`) with seed data for 15 customers, 4 branches, 22 accounts
- Target DDL: `TGT_CUSTOMER_360` — golden record table with upsert support
- Target DDL: `TGT_EXCEPTION_LOG` — append-only audit log with 3 exception reason categories
- IICS Mapplet spec: `MPLT_Cleanse_Customer_Name` — regex-based name standardization
- IICS Mapping spec: `M_Customer_360_ETL` — full 6-phase ETL blueprint
- IICS Connection specs: Oracle + 2 Flat File connections with data quality notes
- Raw data: ATM transaction files for Alexandria, Cairo, Giza (2025)
- Raw data: Credit Card spend files for 2023, 2024, 2025
- `Business_Requirements_Document.pdf` and `Data_Dictionary.pdf` in `/docs`
- `.gitignore` excluding credentials and local IDE configs
- `README.md` with architecture overview, folder map, and quick-start guide
