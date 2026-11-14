# Portfolio 2 — Query Processing and Optimisation

## Project context

PayBridge is a simulated Nigerian digital bank. Its PostgreSQL demo database models customer accounts, transaction metadata, and an append-only double-entry ledger. This portfolio explains how important reads are planned, measured, and improved for the target demo volume of 2,000 customers, 2,666 accounts, and 300,000 ledger entries.

**Deliverables**

- [`database/query_optimization.sql`](../database/query_optimization.sql): statistics refresh, repeatable `EXPLAIN` examples, and optional index candidates.
- [`database/schema.sql`](../database/schema.sql): current schema and baseline indexes.
- [`database/seed_demo.sql`](../database/seed_demo.sql): synthetic-only workload generator.

> No benchmark timings are claimed here. Query plans and timings depend on PostgreSQL version, hardware, cache state, statistics, and data distribution; run the experiments on your own database and record the actual results.

## 1. Query processing overview

For each SQL statement, PostgreSQL parses and rewrites the query, estimates candidate plans using table statistics and cost parameters, selects a plan, then executes it. Common choices include sequential/index scans, nested-loop/hash/merge joins, sorts, and aggregates. The planner's estimates can differ from actual row counts when statistics are stale or data is skewed.

A useful review compares:

- **Estimated rows vs. actual rows:** large differences suggest stale statistics or skew.
- **Buffers:** shared hits/reads indicate cache and I/O activity.
- **Loops and join type:** repeated inner scans may be expensive at scale.
- **Sort/aggregate nodes:** inspect their input volume and whether they spill to disk.
- **Execution time:** compare under equivalent conditions; don't infer improvements from one warm-cache run.

Use `EXPLAIN` to inspect a plan without running a query. Use `EXPLAIN (ANALYZE, BUFFERS)` to execute it and report actual measurements. `ANALYZE` executes the statement, so only use it for safe reads or in a controlled environment for writes.

## 2. Important workloads

### A. Recent transaction history for one account

The query filters by account number, time range, and transaction status, then returns newest transactions first. The schema provides a unique account-number index and source/destination account-time indexes. For a ledger-based statement, the ledger account/time index limits postings to one account and date range, while transaction primary-key lookups provide metadata.

Use keyset pagination for a live feed instead of deep `OFFSET` pagination:

```sql
SELECT t.transaction_id, t.created_at, t.transaction_type, t.status,
       t.amount, t.description
FROM banking_transactions AS t
WHERE t.source_account_id = $1
  AND t.status IN ('COMPLETED', 'REVERSED')
  AND (t.created_at, t.transaction_id) < ($2, $3)
ORDER BY t.created_at DESC, t.transaction_id DESC
LIMIT 50;
```

The first page can omit the cursor predicate. The cursor is the final timestamp and transaction ID from the previous page. If history must include transactions where the account is either source or destination, use two index-friendly branches with `UNION ALL` and deduplicate only if the model permits overlap; avoid an untested broad `OR` on separate columns.

### B. Date-bounded ledger statement

The existing `account_statement` function returns postings for an account over a time interval and computes a running sum. Always constrain both the account and bounded date range. For an opening balance, calculate postings strictly before the period start and add that amount to the window sum; otherwise a running total over the period is a period movement, not the actual account balance.

### C. Available balance

The `account_balances` view calculates the balance from immutable ledger rows. For one account, scope the aggregate to its ledger account rather than aggregating every customer's history in application code. At substantially higher volumes, consider a reconciled balance projection maintained transactionally alongside the ledger, with periodic independent reconciliation; never make an unverified cache the financial source of truth.

### D. Fraud-alert queue

Filter by status and severity and order by creation time. The existing `(status, severity, created_at DESC)` index matches the common queue filter. Validate plans with realistic alert distributions before changing it.

## 3. Baseline indexes and trade-offs

The schema already includes indexes for:

- Unique account number and customer/status account lookups.
- Transactions by source account/time, destination account/time, and status/time.
- Ledger entries by transaction and by ledger account/time.
- Fraud alert status/severity/time.
- Audit history by entity/time and global time.

Indexes can reduce reads and sorting, but cost disk space and slow inserts because each new row also updates relevant indexes. Avoid indexing every column or adding a second index with the same leading columns without plan evidence. On the append-heavy ledger, weigh any covering index against the extra write and storage costs.

## 4. Reproducible plan experiments

Load the schema and synthetic data into a disposable PostgreSQL 15+ database first. Refresh statistics, then run the plans in `database/query_optimization.sql`. Record the following for each test before and after a candidate index:

| Measurement | What to capture |
|---|---|
| Plan | Scan, join, sort, and aggregate nodes |
| Estimated/actual rows | Cardinality-estimation accuracy |
| Buffers | Shared hits and reads |
| Runtime | Planning and execution time, multiple runs |
| Write/storage impact | Index size and representative insert throughput |

Use several runs, note whether the cache is warm or cold, and compare the same query parameters and dataset. Do not treat `EXPLAIN ANALYZE` on a tiny dataset as evidence of production performance.

## 5. Optimization approach

1. Start with the actual slow query and inspect its plan.
2. Refresh statistics using `ANALYZE` after bulk loading or significant data changes.
3. Keep predicates sargable: compare the stored timestamp to a range rather than wrapping the indexed column in `date()`, `lower()`, or a cast.
4. Return only required columns; avoid `SELECT *` in high-volume application paths.
5. Bound result sets and use keyset pagination for descending feeds.
6. Compare account-scoped ledger aggregation with any proposed materialized projection.
7. Consider optional covering/partial indexes only after a plan demonstrates a relevant bottleneck.
8. Re-check write overhead, disk use, and vacuum/analyze behavior after index changes.
9. At a much larger ledger scale, benchmark time partitioning and retention/archival separately; partitioning introduces operational and global-uniqueness considerations.

## 6. Limitations and responsible use

The bundled dataset is synthetic and relatively small by banking standards. This portfolio demonstrates a repeatable query-analysis workflow, not a production service-level guarantee. Keep customer information synthetic in development. Production use requires access controls, secure handling of personal data, backup/recovery testing, monitoring, and independent engineering and compliance review.
