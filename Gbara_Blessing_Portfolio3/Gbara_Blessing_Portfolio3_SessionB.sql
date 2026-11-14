-- PayBridge Concurrency Lab: Session B
-- Attempting concurrent withdrawal on the same account
BEGIN;
SELECT 'Session B attempting concurrent withdrawal' AS status;

-- This statement will block until Session A releases lock
SELECT * FROM accounts WHERE account_number = '7000000001' FOR UPDATE;

-- Attempt withdrawal of NGN 4,000 (which will fail due to insufficient funds post-Session A)
SELECT withdraw(
  (SELECT account_id FROM accounts WHERE account_number = '7000000001'),
  4000.00,
  'concurrency-test-session-B'
);

COMMIT;
