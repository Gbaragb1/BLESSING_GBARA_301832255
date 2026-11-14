# PayBridge database

PostgreSQL schema and synthetic dataset for a simulated Nigerian digital bank. The design covers customer/KYC records, mobile/web/USSD channels, savings/current/wallet accounts, double-entry transaction journals, fraud alerts, and audit history.

## Requirements and setup

- PostgreSQL 15 or newer (uses `pgcrypto` and deferred constraint triggers).
- Create an empty database, then run:

```sh
psql -v ON_ERROR_STOP=1 -d paybridge -f database/schema.sql
psql -v ON_ERROR_STOP=1 -d paybridge -f database/seed_demo.sql
```

The optional seed creates 2,000 fictitious verified customers, 2,666 accounts, and exactly 300,000 ledger entries representing 150,000 balanced journals. Never use generated data as real customer information.

## Core design

- `customers` stores personal/KYC references. BVN and NIN values should be tokenized by a trusted KYC provider; raw identifiers should not be stored here.
- `app_users` distinguishes customers, support, fraud, audit, payment-service and admin identities.
- `accounts` holds customer-facing account state; each maps to a customer liability in `ledger_accounts`. System clearing/cash accounts complete double-entry journals.
- `banking_transactions` stores transaction metadata and idempotency/reference keys. `ledger_entries` is append-only, and a deferred trigger verifies each journal balances at commit.
- `fraud_alerts` tracks rule hits and investigation workflow. `audit_log` captures changes to key operational tables.
- Amounts use `numeric(20,2)` and NGN is explicit. Account numbers are unique 10-digit identifiers.

## Operations

Functions run within the caller's PostgreSQL transaction. Use unique references/idempotency keys per request; production callers should handle duplicate-key responses safely. Set up narrowly scoped database roles and grant execute only on required functions rather than granting direct table writes to services.

```sql
-- Open an account (customer must be KYC VERIFIED)
SELECT open_account('customer-uuid','0123456789','SAVINGS');

-- Money movement: amounts are NGN and must have at most 2 decimal places
SELECT deposit('account-uuid', 25000.00, 'dep-unique-ref');
SELECT withdraw('account-uuid', 2000.00, 'wd-unique-ref');
SELECT transfer('source-account-uuid','destination-account-uuid',500.00,'trf-unique-ref');

-- Compensate a completed transfer; the original journal remains immutable
SELECT reverse_failed_transfer('original-transfer-uuid','reversal-unique-ref');

-- Current balance and a date-bounded statement
SELECT * FROM account_balances WHERE account_id='account-uuid';
SELECT * FROM account_statement('account-uuid',now()-interval '30 days',now());

-- Flag an event for analyst review
INSERT INTO fraud_alerts(customer_id,account_id,transaction_id,severity,rule_code,description)
VALUES ('customer-uuid','account-uuid','transaction-uuid','HIGH','VELOCITY_5M','Unusual transaction velocity');

-- Find any customer account whose account statement does not reconcile
SELECT * FROM balance_audit WHERE NOT reconciles;
```

`reverse_failed_transfer` uses compensating entries and is intentionally limited to a completed transfer that has not already been reversed. A genuinely failed request with no ledger posting should remain `FAILED`; it has no funds to reverse. Adjust the function naming or add a separate retry/settlement workflow if the payment processor's failure semantics differ.

## Production safeguards to add before deployment

This is a starter implementation, not a certified banking core. Add row-level security and grants, secrets management, encryption at rest/in transit, KMS-backed tokenization, data retention and privacy controls, maker-checker approval, strong authentication, rate limiting, monitoring, backups/PITR, disaster recovery, and independent security/compliance review. Restrict direct updates/deletes on ledger and audit data to the database owner; the append-only trigger is defense-in-depth, not protection from a privileged database administrator. Review applicable CBN, NDPR, PCI DSS, and payment-provider requirements before real use.
