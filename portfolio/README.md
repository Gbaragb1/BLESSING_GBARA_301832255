# PayBridge Portfolio

## Portfolio 1 — Database Design and Modelling

A relational database design for a simulated Nigerian digital bank and payments company. The project includes a conceptual ER model, normalized logical model, integrity rules, transaction lifecycle descriptions, and a PostgreSQL implementation with synthetic demo data.

- [Read the full database design and modelling portfolio](portfolio/portfolio-1-database-design-and-modelling.md)
- [PostgreSQL schema](database/schema.sql)
- [Synthetic demo data](database/seed_demo.sql)

**Scope:** customer/KYC records, accounts, deposits, withdrawals, peer-to-peer transfers, immutable double-entry ledger, compensating reversals, fraud alerts, audit trail, account statements, and balance reconciliation.

**Demo scale:** 2,000 customers, 2,666 accounts, and 300,000 synthetic ledger entries.

> Educational simulation only. Do not use real customer data or deploy as a banking core without substantial engineering, security, legal, and compliance review.
