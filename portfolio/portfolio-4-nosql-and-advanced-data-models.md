# Portfolio 4 — NoSQL and Advanced Data Models

## Project context

This portfolio explores a complementary document model for PayBridge's product catalog, fraud-rule configuration, and alert evidence. The PostgreSQL relational ledger remains authoritative for money and balances. NoSQL is considered where flexible, nested, or rapidly evolving data is useful; it does not replace financial controls.

## 1. Relational vs. document responsibilities

| Data | Recommended store | Reason |
|---|---|---|
| Customers, account ownership, KYC state | Relational PostgreSQL | Referential integrity, controlled updates, transactional requirements |
| Transactions and double-entry ledger | Relational PostgreSQL | Strong consistency, auditability, balanced postings, immutable history |
| Fraud rule definitions | Versioned document/config store | Rule structures may vary by detector and evolve independently |
| Alert evidence and feature snapshots | Document store or object storage | Variable shape, nested features, larger evidence payloads |
| Sessions, short-lived device signals | TTL-capable key-value store | Expiration and high-volume access patterns |
| Analytical event archive | Columnar warehouse/object storage | Time-range analytics and large scans, outside operational write path |

Database choice should follow access patterns, consistency needs, data sensitivity, and operational maturity—not a general preference for SQL or NoSQL.

## 2. Example fraud evidence document

Illustrative JSON for a synthetic event. It contains references rather than raw personal identifiers and is not an authoritative transaction record.

```json
{
  "schema_version": 1,
  "alert_id": "e2b55baf-39da-4c72-972b-7ca9f937731c",
  "customer_ref": "synthetic-customer-42",
  "account_ref": "synthetic-account-15",
  "transaction_ref": "synthetic-transaction-883",
  "rule": {
    "code": "VELOCITY_5M",
    "version": 3,
    "severity": "HIGH"
  },
  "observed_at": "2026-01-15T12:30:00Z",
  "features": {
    "transactions_5m": 8,
    "distinct_recipients_1h": 6,
    "device_risk_score": 0.81
  },
  "evidence_refs": ["object://fraud-evidence/demo/alert-883.json"]
}
```

Use schema versioning and validation. Store only necessary features, define retention, and avoid raw BVN/NIN, passwords, card secrets, or unnecessary personal data in event payloads.

## 3. Example MongoDB collection design (optional lab)

```javascript
// fraud_alert_evidence; this is a document-side projection, not the core ledger.
{
  _id: "synthetic-alert-883",
  schemaVersion: 1,
  customerRef: "synthetic-customer-42",
  transactionRef: "synthetic-transaction-883",
  observedAt: ISODate("2026-01-15T12:30:00Z"),
  severity: "HIGH",
  rule: { code: "VELOCITY_5M", version: 3 },
  features: { transactions5m: 8, distinctRecipients1h: 6, deviceRiskScore: 0.81 },
  evidenceRefs: ["object://fraud-evidence/demo/alert-883.json"]
}
```

Candidate indexes for an evidence store (create only for tested access patterns):

```javascript
db.fraud_alert_evidence.createIndex({ transactionRef: 1, observedAt: -1 });
db.fraud_alert_evidence.createIndex({ severity: 1, observedAt: -1 });
db.fraud_alert_evidence.createIndex({ customerRef: 1, observedAt: -1 });
```

## 4. Advanced modeling patterns

- **Polyglot persistence:** keep transactional ledger data relational; use document/analytical systems for purpose-built projections.
- **Event sourcing:** the ledger resembles an event history, but a true event-sourced system also defines event contracts, replay/versioning rules, projections, and correction semantics. Do not equate any ledger table with a complete event-sourcing architecture.
- **CQRS:** separate command validation/posting from read projections such as customer activity feeds; projections are rebuildable and carry freshness metadata.
- **Schema evolution:** add document `schemaVersion`, support backward-compatible readers, and migrate incrementally.
- **Time-series/TTL:** retain transient device/session telemetry only for a documented period; do not expire core financial evidence without an approved retention policy.
- **Data lake/warehouse:** publish minimized, pseudonymized events through an asynchronous pipeline for aggregate analysis, not synchronous balance decisions.

## 5. Consistency and delivery

A document store projection may be eventually consistent. Fraud dashboards should display event time and ingestion/processing time, and operational rules requiring immediate blocking must be enforced synchronously or through a well-defined risk service. Use an outbox in PostgreSQL so that a committed transaction and its notification intent are atomic. A publisher can deliver at least once; consumers should deduplicate by stable event ID. Monitor lag, retries, dead-letter volume, and projection reconciliation.

## 6. Hands-on exercise

1. Load only synthetic alert evidence into a local document database.
2. Validate each document against a versioned JSON schema before writing.
3. Index by transaction reference/time and severity/time.
4. Query a recent high-severity queue with a time bound; inspect the document database's explain plan.
5. Simulate duplicate event delivery and implement idempotent upsert keyed by alert/event ID.
6. Change the document schema version and verify old and new records can both be read during migration.
7. Compare query latency and write cost with a PostgreSQL JSONB prototype at the same dataset size.

## 7. Decision summary and safeguards

NoSQL is appropriate here as a flexible adjunct for variable fraud evidence, transient signals, and read projections—not as a substitute for the authoritative double-entry ledger. Apply encryption, least privilege, retention/deletion controls, data minimization, backups, audit logging, and synthetic-only data in the exercise. Production architecture and privacy obligations need independent review.
