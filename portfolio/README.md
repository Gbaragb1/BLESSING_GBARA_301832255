# PayBridge Portfolio

## Portfolio 1 — Database Design and Modelling

A relational database design for a simulated Nigerian digital bank and payments company. Includes a conceptual ER model, normalized logical model, integrity rules, transaction lifecycle descriptions, and PostgreSQL implementation.

- [Read Portfolio 1: Database Design and Modelling](portfolio/portfolio-1-database-design-and-modelling.md)
- [PostgreSQL schema](database/schema.sql)
- [Synthetic demo data](database/seed_demo.sql)

## Portfolio 2 — Query Processing and Optimisation

A practical PostgreSQL query-planning and performance-analysis guide for account history, statements, ledger balances, and fraud-alert queues. Includes reproducible `EXPLAIN (ANALYZE, BUFFERS)` experiments and carefully marked optional index candidates.

- [Read Portfolio 2: Query Processing and Optimisation](portfolio/portfolio-2-query-processing-and-optimisation.md)
- [Query optimization lab](database/query_optimization.sql)

**Demo scale:** 2,000 synthetic customers, 2,666 accounts, and 300,000 synthetic ledger entries. Educational simulation only; not a production banking core.
