# Portfolio 1 — Database Design and Modelling

## Project brief

**Organization:** PayBridge, a simulated Nigerian digital bank and payments company.  
**Business scope:** Retail accounts, deposits, withdrawals, peer-to-peer transfers, fraud monitoring, KYC, and audit support.  
**Users:** Customers using mobile, web, and USSD; support staff; fraud analysts; auditors; and backend payment services.  
**Scale target:** Approximately 2,000 customers, 2,666 accounts, and 300,000 synthetic ledger rows.

This portfolio presents the conceptual and logical model, core integrity rules, and implementation mapping for a PostgreSQL database. The executable schema and optional demo-data generator are in [`database/schema.sql`](../database/schema.sql) and [`database/seed_demo.sql`](../database/seed_demo.sql).

> **Safety note:** This is a learning/simulation project, not a production banking core. Use only synthetic data. Real deployment requires qualified security, legal, compliance, and banking-system review.

## 1. Requirements and design goals

### Functional requirements

1. Register customers and maintain KYC review status.
2. Open and manage customer accounts (savings, current, wallet).
3. Post deposits, withdrawals, and peer-to-peer transfers in NGN.
4. Provide account balances and date-bounded statements.
5. Reverse a completed transfer through a compensating journal, preserving history.
6. Record suspicious activity and support alert assignment/resolution.
7. Retain an audit trail and support balance reconciliation.
8. Associate actions with user roles and channels (mobile, web, USSD, API, etc.).

### Non-functional requirements

- Use precise fixed-point money (`numeric(20,2)`), never floating point.
- Keep a complete, append-only, double-entry ledger.
- Make account references, transaction references, and idempotency keys unique.
- Use foreign keys and checks for referential and domain integrity.
- Support common customer/account history queries with indexes.
- Store KYC identifiers as provider-issued tokens/references, not raw BVN/NIN.

## 2. Conceptual model

```mermaid
erDiagram
    CUSTOMERS ||--o{ ACCOUNTS : owns
    CUSTOMERS ||--o| APP_USERS : "may sign in as"
    ACCOUNTS ||--|| LEDGER_ACCOUNTS : maps_to
    LEDGER_ACCOUNTS ||--o{ LEDGER_ENTRIES : receives
    BANKING_TRANSACTIONS ||--|{ LEDGER_ENTRIES : posts
    BANKING_TRANSACTIONS o|--o| BANKING_TRANSACTIONS : reverses
    APP_USERS o|--o{ BANKING_TRANSACTIONS : initiates
    APP_USERS o|--o{ FRAUD_ALERTS : assigned_to
    CUSTOMERS o|--o{ FRAUD_ALERTS : concerns
    ACCOUNTS o|--o{ FRAUD_ALERTS : concerns
    BANKING_TRANSACTIONS o|--o{ FRAUD_ALERTS : triggers
    APP_USERS o|--o{ AUDIT_LOG : performs

    CUSTOMERS {
      uuid customer_id PK
      text first_name
      text last_name
      text email UK
      text phone_e164 UK
      text bvn_token UK
      text nin_token UK
      kyc_status kyc_state
    }
    APP_USERS {
      uuid user_id PK
      text username UK
      text password_hash
      text user_role
      uuid customer_id FK
      boolean is_active
    }
    ACCOUNTS {
      uuid account_id PK
      uuid customer_id FK
      uuid ledger_account_id FK_UK
      char account_number UK
      text account_type
      account_status status
      char currency
    }
    LEDGER_ACCOUNTS {
      uuid ledger_account_id PK
      text account_code UK
      text account_name
      account_class account_class
      numeric balance
    }
    BANKING_TRANSACTIONS {
      uuid transaction_id PK
      transaction_type transaction_type
      transaction_status status
      numeric amount
      uuid source_account_id FK
      uuid destination_account_id FK
      text external_reference UK
      text idempotency_key UK
      uuid related_transaction_id FK
    }
    LEDGER_ENTRIES {
      bigint ledger_entry_id PK
      uuid transaction_id FK
      uuid ledger_account_id FK
      ledger_side side
      numeric amount
      timestamptz created_at
    }
    FRAUD_ALERTS {
      uuid alert_id PK
      uuid customer_id FK
      uuid account_id FK
      uuid transaction_id FK
      text severity
      text rule_code
      alert_status status
      uuid assigned_to FK
    }
    AUDIT_LOG {
      bigint audit_id PK
      uuid actor_user_id FK
      text action
      text entity_type
      text entity_id
      jsonb old_values
      jsonb new_values
      timestamptz occurred_at
    }
```

**Relationship interpretation:** A customer may own multiple accounts. Each customer-facing account maps to exactly one customer ledger account, while system ledger accounts represent cash/settlement and other control accounts. A transaction posts one or more immutable ledger entries. A reversal is a new transaction linked to the original. Optional alert relationships allow a rule to concern a customer, account, transaction, or combination of those entities.

## 3. Logical model and data dictionary

| Relation | Purpose | Important attributes and constraints |
|---|---|---|
| `customers` | Customer profile and KYC status | UUID PK; unique phone, optional email and token references; controlled KYC enum; timestamps |
| `app_users` | Authenticated identities and staff roles | UUID PK; unique username; password hash only; role check; optional one-to-one customer association for customer users |
| `ledger_accounts` | Customer and system accounting buckets | UUID PK; unique account code; account class; NGN; balance field reserved for accounting metadata (posted balance is derived from entries) |
| `accounts` | Customer-facing retail accounts | UUID PK; customer FK; unique ledger-account FK; unique 10-digit account number; account type and lifecycle state |
| `banking_transactions` | Business transaction metadata | UUID PK; transaction type/status; positive amount; source/destination FKs; unique external/idempotency references; optional original-transaction FK |
| `ledger_entries` | Immutable debit/credit postings | Identity PK; transaction and ledger-account FKs; positive amount; debit/credit side; indexed account/time and transaction |
| `fraud_alerts` | Alert triage and investigation | UUID PK; optional customer/account/transaction; severity and status; rule code; optional assigned analyst |
| `audit_log` | Change history for sensitive entities | Identity PK; actor; action/entity; old/new JSON snapshots; request metadata and timestamp |

### Derived views

- `account_balances` computes account balance from its ledger postings (customer accounts are credit-normal).
- `balance_audit` compares the derived account balance with its ledger aggregate for reconciliation.
- `account_statement(account_id, from, to)` yields transaction postings and a running balance for the requested period.

## 4. Normalization and rationale

The operational model is designed to satisfy approximately **Third Normal Form (3NF)**:

- Customer identity/KYC attributes live in `customers`, not repeated on every account or transaction.
- Account ownership and account type are stored once per account in `accounts`.
- Ledger account definitions are separated from individual posted entries.
- Transaction metadata is stored once in `banking_transactions`; its accounting effects are represented as rows in `ledger_entries`.
- Fraud workflow and audit snapshots are separate concerns and do not duplicate core transaction records.
- Controlled states use PostgreSQL enums or checks; optional future product/configuration catalogs could replace text checks if the domain grows.

Balances are derived rather than stored as mutable customer-account values. This avoids treating a cached value as financial truth; a production system may maintain a reconciled projection for performance, but the ledger must remain authoritative.

## 5. Integrity and business rules

1. Only a KYC-verified customer can open an account.
2. Accounts have one customer owner and one associated customer ledger account.
3. All monetary values are positive NGN amounts with at most two decimal places.
4. A posted journal must have equal total debits and credits. A deferred constraint trigger checks the journal at transaction commit.
5. Ledger rows cannot be updated or deleted. Corrections are made by a new compensating journal.
6. Deposits, withdrawals, and transfers require active accounts; withdrawals/transfers check available funds.
7. A transfer's source and destination must differ. Both accounts are locked in deterministic order during posting.
8. An idempotency/reference key prevents duplicate request posting when callers retry.
9. Reversal is represented by a new completed `REVERSAL` transaction, linked to the original; a completed transfer may only be reversed once.
10. A transaction with no ledger posting that failed at the provider remains failed; it should not be “reversed.”
11. Audit events identify entity/action and preserve old/new values for supported sensitive table changes.
12. Raw BVN/NIN and passwords must never be stored; retain provider tokens and salted, slow password hashes produced by a trusted identity service.

## 6. Workload and indexing

The model is sized for a portfolio-scale synthetic dataset: 2,000 customer profiles, 2,666 accounts, and 300,000 ledger lines. Indexes support:

- Customer-to-account lookups and status filtering.
- Account statement pagination by account and timestamp.
- Ledger retrieval by transaction or ledger account/time.
- Transaction history by source/destination and status/time.
- Open fraud-alert queues by status, severity, and creation time.
- Audit history by entity and timestamp.

For larger production workloads, consider partitioning high-volume `ledger_entries`, transaction and audit tables by time, carefully retaining global uniqueness/idempotency semantics and validating query plans.

## 7. Example lifecycle flows

### Open account

`open_account(customer_id, account_number, type)` validates KYC, creates a customer-class ledger account, then creates the customer-facing account linked to it.

### Deposit

Within one database transaction: create completed transaction metadata; debit the system cash/settlement ledger; credit the customer's liability ledger. Both entries share the transaction ID.

### Transfer

Lock both active accounts; check source balance; create a completed transaction; debit the source customer ledger and credit the destination customer ledger. Commit only when the deferred balance check passes.

### Reversal

Lock the original transfer and accounts; reject non-completed or already reversed transfers; post the inverse debit/credit entries as a new transaction referencing the original. Preserve the original transaction and ledger entries.

### Fraud and audit

Insert an alert with a rule code, severity, and links to the relevant activity. Analyst assignment and resolution update its workflow state. Sensitive table changes are copied into `audit_log` by database triggers.

## 8. Implementation files and run steps

- PostgreSQL implementation: [`database/schema.sql`](../database/schema.sql)
- Optional synthetic dataset: [`database/seed_demo.sql`](../database/seed_demo.sql)

```sh
createdb paybridge
psql -v ON_ERROR_STOP=1 -d paybridge -f database/schema.sql
psql -v ON_ERROR_STOP=1 -d paybridge -f database/seed_demo.sql
```

The seed is intended for an empty database. Validate row counts and reconciliation after loading:

```sql
SELECT count(*) FROM customers;
SELECT count(*) FROM accounts;
SELECT count(*) FROM ledger_entries;
SELECT count(*) FROM balance_audit WHERE NOT reconciles;
```

Expected counts: 2,000 customers, 2,666 accounts, and 300,000 ledger rows. The last query should return no rows for an internally consistent dataset.

## 9. Limitations and next steps

- This model is for demonstration and does not implement a full payment-provider state machine, fees, disputes, settlement windows, multi-currency, joint accounts, limits, or maker-checker approvals.
- A production API should use a trusted authentication/authorization layer, transaction-bound identity, restricted database roles, connection security, encryption, key management, backup/PITR, monitoring, and tested disaster recovery.
- Review privacy, retention, CBN, NDPR, PCI DSS (where applicable), and payment-provider obligations with qualified specialists before any real-world use.
- Add automated integration tests for concurrent transfers, idempotent retries, duplicate reversals, transaction rollback, statement pagination, and reconciliation.
