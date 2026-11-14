-- PayBridge Concurrency Lab: Session A
-- Demonstrating Row-Level Locking and Double-Spend Prevention
BEGIN;
SELECT 'Session A started withdrawal transaction' AS status;

-- Acquire exclusive row lock on source account
SELECT * FROM accounts WHERE account_number = '7000000001' FOR UPDATE;

-- Simulate processing delay holding lock
SELECT pg_sleep(3);

-- Perform withdrawal of NGN 4,000
SELECT withdraw(
  (SELECT account_id FROM accounts WHERE account_number = '7000000001'),
  4000.00,
  'concurrency-test-session-A'
);

COMMIT;
SELECT 'Session A committed successfully' AS status;
