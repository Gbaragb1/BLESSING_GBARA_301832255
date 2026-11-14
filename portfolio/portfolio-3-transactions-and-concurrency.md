# Portfolio 3 — Transactions and Concurrency

## Project context

PayBridge is a simulated Nigerian digital bank. Its PostgreSQL prototype supports deposits, withdrawals, peer-to-peer transfers, and compensating reversals using a double-entry ledger. This portfolio examines how transaction boundaries, isolation, row locking, retries, and idempotency protect correctness when multiple requests run concurrently.

**Related implementation:** [`database/schema.sql`](../database/schema.sql).  
**Scope:** educational exercise only; it is not certified or suitable as a production banking core.

## 1. Transaction properties and invariants

The money movement operations should satisfy ACID properties:

- **Atomicity:** transaction metadata and all ledger postings commit together, or none do.
- **Consistency:** constraints and deferred journal checks preserve valid states, including equal debits and credits.
- **Isolation:** concurrent operations must not spend the same available funds twice.
- **Durability:** committed postings survive failures according to the database's durability and backup configuration.

Core invariants:

1. A journal's debit total equals its credit total.
2. A customer account's balance is derived from immutable ledger entries.
3. A withdrawal/transfer cannot reduce available funds below zero (unless a separately modeled overdraft policy permits it).
4. A retried request with the same idempotency key must not create another movement.
5. A reversal adds new entries and never edits the original ledger rows.

## 2. Transaction boundaries

Each business operation should be executed in one database transaction. A successful transfer has one transaction row plus at least two ledger postings; the deferred constraint trigger validates the final journal at commit. A failed operation must roll back all writes. External payment-provider calls should not be performed while holding database locks; use an outbox/state-machine pattern for external side effects in a real integration.

Example caller-controlled transaction:

```sql
BEGIN;
SELECT transfer('source-account-uuid','destination-account-uuid',500.00,'unique-request-key');
COMMIT;
```

The schema's function performs the database writes; the caller's transaction controls commit/rollback. Handle unique-key violations and retryable serialization/deadlock errors distinctly.

## 3. Concurrency risks and controls

| Risk | Example | Mitigation |
|---|---|---|
| Lost update | Two requests overwrite a mutable balance field | Ledger is authoritative; avoid mutable customer balance as source of truth |
| Double spend | Two withdrawals each observe the same balance | Lock the account row before checking funds and inserting postings; ensure every money-moving path obeys this rule |
| Deadlock | Concurrent A→B and B→A transfers lock in opposite order | Acquire both account locks in deterministic order; retry deadlock victims safely |
| Duplicate request | Client times out then retries a completed transfer | Unique idempotency key, stable request identity, and response replay at the API/service layer |
| Partial journal | Transaction metadata commits without both postings | Single DB transaction and deferred balanced-journal check |
| Conflicting reversal | Two workers reverse one transfer at once | Lock original transaction; enforce one reversal per original with a unique/partial constraint in hardened implementation |
| Provider uncertainty | Provider timeout after it accepted a payment | Durable pending state, callback reconciliation, outbox/inbox, and idempotent settlement handling |

**Important implementation review:** the prototype uses unique transaction idempotency keys and row locks in its helper functions. A production design should additionally provide a database-enforced uniqueness rule on reversal relationships and ensure all application writers use the same locking protocol. Application-side “check then insert” alone is not safe against racing requests.

## 4. Isolation strategy

PostgreSQL's default `READ COMMITTED` isolation can be sufficient for the prototype if critical account rows are locked before reading the derived balance and all writers follow the same protocol. The lock serializes money movements on the same account. Deterministic locking of both accounts reduces deadlocks, but deadlocks remain possible and should be retried.

`REPEATABLE READ` provides a stable snapshot but does not automatically solve every write-skew or check-then-act problem. `SERIALIZABLE` detects serialization anomalies and aborts one transaction when necessary; callers must implement bounded retries with backoff and stable idempotency keys. Select isolation based on explicit invariants and test results, not assumption.

## 5. Safe retry and idempotency pattern

- Generate a client/request idempotency key once and reuse it across retries.
- Enforce uniqueness in the database with a key scoped to the correct caller/operation in production.
- On duplicate submission, retrieve and return the original result rather than running a second movement.
- Retry only errors known to be transient (for example serialization failure or deadlock), with bounded exponential backoff and jitter.
- Do not retry an uncertain provider side effect as a new payment; reconcile with provider reference/status first.
- Never create a new idempotency key merely because a response timed out.

## 6. Reversal and compensation

A payment that never posted and is definitively failed should remain `FAILED`; no ledger reversal is required. If a completed transfer must be undone, post a compensating transaction that debits the recipient ledger and credits the sender ledger. The original journal remains unchanged. This distinction preserves auditability and avoids treating a failed attempt as settled money.

## 7. Concurrency test lab

Use a disposable database containing synthetic data. Pick one source account with sufficient funds and execute the following from two independent psql sessions at the same time. Adapt UUIDs by looking up `account_id` from the account number.

**Session A and Session B (replace IDs and use distinct request keys):**

```sql
BEGIN;
SELECT withdraw('source-account-uuid', 100.00, 'concurrency-test-A');
-- Pause briefly here in one session to overlap operations, then:
COMMIT;
```

Run the analogous operation in the other session with `concurrency-test-B`. With a balance that can fund only one withdrawal, at most one should succeed. Check the resulting balance and journal rows after the sessions finish. Repeat with transfers in opposite directions to observe potential lock contention and verify deterministic account locking.

Do not use production accounts or real credentials. Capture SQLSTATE, error messages, final balance, and ledger totals; clean up only by resetting the disposable database, not by editing ledger history.

## 8. Production hardening checklist

- Include reversal uniqueness as a database constraint (e.g. unique partial index on `related_transaction_id` for reversal transactions).
- Add concurrency integration tests and fault-injection tests for commit/connection loss.
- Make account locks part of a documented, universal write protocol.
- Scope idempotency keys to tenant/customer/operation and store a stable response record.
- Use an outbox/inbox for provider events; reconcile asynchronous status changes.
- Define bounded retry policy for deadlocks and serialization errors.
- Restrict direct table writes; expose least-privilege stored procedures or service APIs.
- Monitor lock waits, deadlocks, long transactions, retries, and reconciliation exceptions.

This exercise focuses on transactional correctness, not on guaranteeing production throughput or regulatory compliance.
