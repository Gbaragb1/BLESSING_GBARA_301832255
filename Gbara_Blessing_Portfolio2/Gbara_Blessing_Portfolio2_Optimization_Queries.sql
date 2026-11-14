-- PayBridge Query Optimization Suite (PostgreSQL 15+)
-- Student: Blessing Gbara (301832255)

-- Workload 1: Recent Transaction Feed
SELECT t.transaction_id, t.created_at, t.transaction_type, t.status, t.amount, t.description
FROM banking_transactions AS t
JOIN accounts AS a ON a.account_id = t.source_account_id
WHERE a.account_number = '7000000001'
  AND t.status IN ('COMPLETED', 'REVERSED')
  AND t.created_at >= now() - interval '30 days'
ORDER BY t.created_at DESC, t.transaction_id DESC
LIMIT 50;

-- Workload 2: Available Account Balance via Ledger Aggregation
SELECT COALESCE(sum(CASE WHEN le.side = 'CREDIT' THEN le.amount ELSE -le.amount END), 0)::numeric(20,2) AS available_balance
FROM accounts AS a
JOIN ledger_entries AS le ON le.ledger_account_id = a.ledger_account_id
WHERE a.account_number = '7000000001';

-- Workload 3: Date-Bounded Statement Extract
SELECT le.created_at, t.transaction_id, t.transaction_type, le.side, le.amount
FROM accounts AS a
JOIN ledger_entries AS le ON le.ledger_account_id = a.ledger_account_id
JOIN banking_transactions AS t ON t.transaction_id = le.transaction_id
WHERE a.account_number = '7000000001'
  AND t.created_at >= now() - interval '30 days'
  AND t.status IN ('COMPLETED', 'REVERSED')
ORDER BY t.created_at, t.transaction_id
LIMIT 500;

-- Workload 4: High-Severity Fraud Queue
SELECT alert_id, severity, rule_code, description, created_at
FROM fraud_alerts
WHERE status IN ('OPEN', 'INVESTIGATING', 'ESCALATED')
  AND severity IN ('HIGH', 'CRITICAL')
ORDER BY severity DESC, created_at DESC
LIMIT 100;
