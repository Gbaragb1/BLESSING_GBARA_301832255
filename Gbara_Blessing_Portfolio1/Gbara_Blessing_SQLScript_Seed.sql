-- Optional synthetic dataset for a new PayBridge database.
-- Creates exactly 2,000 customers, 2,666 accounts and 300,000 immutable ledger rows
-- (150,000 balanced two-line journals). Generated records are fictitious.
BEGIN;
INSERT INTO customers(first_name,last_name,email,phone_e164,kyc_state)
SELECT 'Customer'||n,'Demo','customer'||n||'@example.test','+23480'||lpad(n::text,8,'0'),'VERIFIED'
FROM generate_series(1,2000) AS g(n);

WITH numbered AS (
  SELECT customer_id,row_number() OVER (ORDER BY created_at,customer_id) AS n FROM customers
  WHERE email LIKE 'customer%@example.test'
), new_accounts AS (
  SELECT n,customer_id FROM numbered CROSS JOIN LATERAL generate_series(1,2) AS x(i) WHERE n<=666
  UNION ALL
  SELECT n,customer_id FROM numbered WHERE n>666
), numbered_accounts AS (
  SELECT *,row_number() OVER (ORDER BY n,i NULLS FIRST) AS seq FROM new_accounts
  LEFT JOIN LATERAL (SELECT 1 AS i) x ON true
)
INSERT INTO ledger_accounts(account_code,account_name,account_class)
SELECT 'SEED-'||lpad(seq::text,4,'0'),'Synthetic customer ledger '||seq,'CUSTOMER'
FROM numbered_accounts;

WITH numbered AS (
  SELECT customer_id,row_number() OVER (ORDER BY created_at,customer_id) AS n FROM customers
  WHERE email LIKE 'customer%@example.test'
), allocated AS (
  SELECT customer_id,row_number() OVER (ORDER BY n,copy_no) AS seq
  FROM numbered CROSS JOIN LATERAL generate_series(1,CASE WHEN n<=666 THEN 2 ELSE 1 END) AS copies(copy_no)
), ledgers AS (
  SELECT ledger_account_id,row_number() OVER (ORDER BY account_code) AS seq FROM ledger_accounts WHERE account_code LIKE 'SEED-%'
)
INSERT INTO accounts(customer_id,ledger_account_id,account_number,account_type)
SELECT al.customer_id,l.ledger_account_id,lpad((7000000000+al.seq)::text,10,'0'),
       CASE WHEN al.seq%3=0 THEN 'CURRENT' WHEN al.seq%3=1 THEN 'SAVINGS' ELSE 'WALLET' END
FROM allocated al JOIN ledgers l USING(seq);

-- Every generated journal moves value between a customer account and system cash.
-- Transactions are deposits/withdrawals with paired debit/credit postings.
INSERT INTO banking_transactions(transaction_type,status,amount,source_account_id,external_reference,idempotency_key,channel,completed_at,description)
SELECT CASE WHEN g.n%2=0 THEN 'DEPOSIT'::transaction_type ELSE 'WITHDRAWAL'::transaction_type END,
       'COMPLETED', (100 + (g.n%100000)/100.0)::numeric(20,2), a.account_id,
       'SEED-TX-'||g.n,'SEED-IDEM-'||g.n,'SYSTEM',now()-((g.n%365)||' days')::interval,'Synthetic historical activity'
FROM generate_series(1,150000) AS g(n)
JOIN accounts a ON a.account_number=lpad((7000000000+((g.n-1)%2666+1))::text,10,'0');

WITH tx AS (SELECT transaction_id,source_account_id,amount,transaction_type,row_number() OVER(ORDER BY transaction_id) AS n
            FROM banking_transactions WHERE external_reference LIKE 'SEED-TX-%'),
acct AS (SELECT account_id,ledger_account_id FROM accounts), cash AS
(SELECT ledger_account_id FROM ledger_accounts WHERE account_code='SYS-CASH')
INSERT INTO ledger_entries(transaction_id,ledger_account_id,side,amount,created_at)
SELECT tx.transaction_id, CASE WHEN tx.transaction_type='DEPOSIT' THEN cash.ledger_account_id ELSE acct.ledger_account_id END,
       CASE WHEN tx.transaction_type='DEPOSIT' THEN 'DEBIT'::ledger_side ELSE 'DEBIT'::ledger_side END,
       tx.amount,now()-(tx.n%365||' days')::interval
FROM tx JOIN acct ON acct.account_id=tx.source_account_id CROSS JOIN cash
UNION ALL
SELECT tx.transaction_id, CASE WHEN tx.transaction_type='DEPOSIT' THEN acct.ledger_account_id ELSE cash.ledger_account_id END,
       CASE WHEN tx.transaction_type='DEPOSIT' THEN 'CREDIT'::ledger_side ELSE 'CREDIT'::ledger_side END,
       tx.amount,now()-(tx.n%365||' days')::interval
FROM tx JOIN acct ON acct.account_id=tx.source_account_id CROSS JOIN cash;
COMMIT;
