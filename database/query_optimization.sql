-- PayBridge query processing and optimization lab (PostgreSQL 15+)
-- Run against the disposable demo database after schema and seed loading.
-- EXPLAIN ANALYZE executes the SELECT statements below; no data is modified.

ANALYZE customers;
ANALYZE accounts;
ANALYZE banking_transactions;
ANALYZE ledger_entries;
ANALYZE fraud_alerts;

-- 1) Recent transaction feed for a seeded account, using account-number lookup and
--    source-account/time index. Capture estimates, actual rows, buffers, and time.
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT t.transaction_id,t.created_at,t.transaction_type,t.status,t.amount,t.description
FROM banking_transactions AS t
JOIN accounts AS a ON a.account_id=t.source_account_id
WHERE a.account_number='7000000001'
  AND t.status IN ('COMPLETED','REVERSED')
  AND t.created_at >= now()-interval '30 days'
ORDER BY t.created_at DESC,t.transaction_id DESC
LIMIT 50;

-- 2) Account balance scoped to one ledger account. Compare with a query that
--    aggregates all customer ledger entries; this shape should keep work focused.
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT COALESCE(sum(CASE WHEN le.side='CREDIT' THEN le.amount ELSE -le.amount END),0)::numeric(20,2)
       AS available_balance
FROM accounts AS a
JOIN ledger_entries AS le ON le.ledger_account_id=a.ledger_account_id
WHERE a.account_number='7000000001';

-- 3) Ledger statement scan over a bounded interval for one account.
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT le.created_at,t.transaction_id,t.transaction_type,le.side,le.amount
FROM accounts AS a
JOIN ledger_entries AS le ON le.ledger_account_id=a.ledger_account_id
JOIN banking_transactions AS t ON t.transaction_id=le.transaction_id
WHERE a.account_number='7000000001'
  AND t.created_at >= now()-interval '30 days'
  AND t.created_at < now()
  AND t.status IN ('COMPLETED','REVERSED')
ORDER BY t.created_at, t.transaction_id
LIMIT 500;

-- 4) Fraud analyst queue; existing index starts with (status, severity, created_at DESC).
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT alert_id,severity,rule_code,description,created_at
FROM fraud_alerts
WHERE status IN ('OPEN','INVESTIGATING','ESCALATED')
  AND severity IN ('HIGH','CRITICAL')
ORDER BY severity DESC,created_at DESC
LIMIT 100;

-- Optional index candidates: create only if plan evidence justifies them.
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS ledger_account_tx_cover_idx
--   ON ledger_entries(ledger_account_id,transaction_id) INCLUDE(side,amount,created_at);
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS completed_source_history_idx
--   ON banking_transactions(source_account_id,created_at DESC,transaction_id DESC)
--   INCLUDE(transaction_type,amount,description)
--   WHERE status IN ('COMPLETED','REVERSED');
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS completed_destination_history_idx
--   ON banking_transactions(destination_account_id,created_at DESC,transaction_id DESC)
--   INCLUDE(transaction_type,amount,description)
--   WHERE status IN ('COMPLETED','REVERSED');
-- CREATE INDEX CONCURRENTLY cannot run inside a transaction block. Run optional
-- statements individually in a maintenance window, then ANALYZE and re-test.
