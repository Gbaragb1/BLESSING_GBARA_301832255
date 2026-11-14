================================================================================
MIVA OPEN UNIVERSITY | FACULTY OF COMPUTING & APPLIED SCIENCES
MIT 8103: ADVANCED DATABASE SYSTEMS (CONTINUOUS ASSESSMENT)
ACADEMIC SESSION: 2026/2027 (SEPTEMBER COHORT) | TOTAL MARKS: 40
================================================================================

STUDENT INFORMATION:
- Student Name:   Blessing Gbara
- Student ID:     301832255
- Programme:      Master of Science in Information Technology (M.Sc. IT)
- Course:         MIT 8103 – Advanced Database Systems
- Target Degree:  Miva Open University
- Submission Date: November 2026
- Case Study:     PayBridge — Simulated Nigerian Digital Bank & Payments Platform
- Primary Database: PostgreSQL 15+ (pgcrypto, deferred triggers, double-entry ledger)
- GitHub Repo:    https://github.com/winnerbanjo/Gbara_Blessing_301832255

================================================================================
TABLE OF CONTENTS
================================================================================
1. Case Study Overview (PayBridge Digital Bank)
2. Submission Structure & Mandatory Naming Conventions
3. Portfolio 1: Database Design & Relational Modeling (7 Marks)
4. Portfolio 2: Query Processing & Index Optimization (7 Marks)
5. Portfolio 3: Transactions & Concurrency Control (7 Marks)
6. Portfolio 4: NoSQL & Advanced Document Models (7 Marks)
7. Portfolio 5: Distributed & Cloud Databases (6 Marks)
8. Final Synthesis & Executive Summary (6 Marks)
9. Step-by-Step Instructions to Reproduce Practical Demonstrations
10. Testing, Verification & Empirical Evidence Summary
11. Academic References
12. Formal Academic Integrity & AI-Use Declaration

================================================================================
1. CASE STUDY OVERVIEW (PAYBRIDGE DIGITAL BANK)
================================================================================
PayBridge is an enterprise-grade digital banking and payment processing engine 
designed to handle retail customer onboarding, KYC verification (BVN/NIN tokenization), 
savings/current/wallet account management, deposit/withdrawal operations, peer-to-peer 
transfers, double-entry ledger accounting, fraud detection telemetry, and multi-region 
resilience for Nigeria's financial services ecosystem.

The database architecture is designed to address two core enterprise requirements:
a) Absolute Financial Integrity: An append-only double-entry general ledger 
   governed by deferred constraint triggers where debits must balance credits at 
   transaction commit, guaranteeing zero ledger corruption.
b) High-Throughput Read Scaling & Risk Intelligence: Polyglot persistence 
   combining relational ACID consistency with NoSQL document projections for 
   rapid fraud alert investigation and distributed failover topologies.

================================================================================
2. SUBMISSION STRUCTURE & MANDATORY NAMING CONVENTIONS
================================================================================
Per Miva MIT 8103 continuous assessment instructions:
- Top-Level Archive: Gbara_Blessing_301832255.zip
- Main Directory inside ZIP: Gbara_Blessing_301832255/
- Standalone Readme: Gbara_Blessing_README.txt
- Every assignment file and directory strictly follows: Gbara_Blessing_DocumentType.extension

DIRECTORY & FILE INVENTORY:
Gbara_Blessing_301832255/
│
├── Gbara_Blessing_README.txt                          (Master Assignment Overview)
├── Gbara_Blessing_Master_README.md                     (Markdown Repository Portal)
│
├── Gbara_Blessing_Portfolio1/                         (Portfolio 1: Relational Design)
│   ├── Gbara_Blessing_Portfolio1_README.md            (Module Guide)
│   ├── Gbara_Blessing_Portfolio1_Report.md            (Academic Design Document & 3NF Analysis)
│   ├── Gbara_Blessing_SQLScript_Schema.sql            (Master PostgreSQL DDL & Trigger Schema)
│   ├── Gbara_Blessing_SQLScript_Seed.sql              (2,000 Customers & 300,000 Ledger Entries)
│   ├── Gbara_Blessing_ERD.md                          (Mermaid ERD with Data Dictionary)
│   └── Gbara_Blessing_Database_Testing_Report.md      (Constraint & Schema Verification Logs)
│
├── Gbara_Blessing_Portfolio2/                         (Portfolio 2: Query Optimization)
│   ├── Gbara_Blessing_Portfolio2_README.md            (Module Guide)
│   ├── Gbara_Blessing_Portfolio2_Report.md            (Optimization Benchmark Report)
│   ├── Gbara_Blessing_Portfolio2_Optimization_Queries.sql (4 Production Analytical Queries)
│   └── Gbara_Blessing_Portfolio2_Execution_Plans.txt  (EXPLAIN ANALYZE BUFFERS Before/After Logs)
│
├── Gbara_Blessing_Portfolio3/                         (Portfolio 3: Transactions & Concurrency)
│   ├── Gbara_Blessing_Portfolio3_README.md            (Module Guide)
│   ├── Gbara_Blessing_Portfolio3_Report.md            (Concurrency, Row Locking & ACID Report)
│   ├── Gbara_Blessing_Portfolio3_SessionA.sql         (Dual-Session Client A Test Script)
│   ├── Gbara_Blessing_Portfolio3_SessionB.sql         (Dual-Session Client B Test Script)
│   └── Gbara_Blessing_Portfolio3_Execution_Logs.txt   (Live Session Telemetry & Lock Wait Logs)
│
├── Gbara_Blessing_Portfolio4/                         (Portfolio 4: NoSQL Document Model)
│   ├── Gbara_Blessing_Portfolio4_README.md            (Module Guide)
│   ├── Gbara_Blessing_Portfolio4_Report.md            (Comparative Paradigm Report)
│   ├── Gbara_Blessing_Portfolio4_FraudEvidence.json   (Denormalized JSON Fraud Telemetry Dataset)
│   ├── Gbara_Blessing_Portfolio4_CRUD_Aggregations.js (MongoDB Shell MQL Aggregation Pipelines)
│   ├── Gbara_Blessing_Portfolio4_Verification.py      (Python Verification Engine)
│   └── Gbara_Blessing_Portfolio4_Execution_Results.txt (Verified Output Logs)
│
├── Gbara_Blessing_Portfolio5/                         (Portfolio 5: Distributed Databases)
│   ├── Gbara_Blessing_Portfolio5_README.md            (Module Guide)
│   ├── Gbara_Blessing_Portfolio5_Report.md            (Distributed Banking Topology Report)
│   ├── Gbara_Blessing_Portfolio5_Primary.conf         (PostgreSQL Primary WAL & Streaming Config)
│   ├── Gbara_Blessing_Portfolio5_Standby.conf         (PostgreSQL Standby Hot Standby Config)
│   ├── Gbara_Blessing_Portfolio5_Replication.sql      (Replication Slot & Failover Commands)
│   ├── Gbara_Blessing_Portfolio5_Sharding_Simulator.py (2PC & Sharding Simulator)
│   └── Gbara_Blessing_Portfolio5_Execution_Logs.txt   (Simulation Verification Logs)
│
├── Gbara_Blessing_FinalDocumentation/                 (Final Synthesis & Governance)
│   ├── Gbara_Blessing_Final_Summary_Report.md         (2-3 Page Executive Synthesis)
│   ├── Gbara_Blessing_AI_Use_Declaration.md           (Academic Integrity Disclosure)
│   └── Gbara_Blessing_Rubric_Checklist.md             (Self-Assessment Matrix)
│
└── Gbara_Blessing_Evidence/                           (Evidence & Telemetry)
    └── Gbara_Blessing_Evidence_Log.txt                (Audit Trail & Capture Notes)

================================================================================
3. PORTFOLIO 1: DATABASE DESIGN & RELATIONAL MODELING (7 MARKS)
================================================================================
- Relational Schema: 8 core tables (customers, app_users, ledger_accounts, accounts, 
  banking_transactions, ledger_entries, fraud_alerts, audit_log).
- Integrity Constraints: UUID primary keys (gen_random_uuid()), check constraints 
  validating 10-digit account numbers, NGN currency isolation, positive amounts, 
  and tokenized BVN/NIN identifiers ensuring NDPR/CBN privacy compliance.
- Double-Entry Engine: Every money movement creates immutable records in 
  ledger_entries. A deferred trigger (fn_enforce_balanced_journal) validates 
  that SUM(debits) = SUM(credits) before commit, rejecting unbalanced mutations.
- Third Normal Form (3NF) Justification: Complete normalization decomposing entities 
  into independent relations, eliminating partial and transitive dependencies while 
  enforcing strict referential integrity.

================================================================================
4. PORTFOLIO 2: QUERY PROCESSING & INDEX OPTIMIZATION (7 MARKS)
================================================================================
- Production Benchmark Dataset: 2,000 customers, 2,666 active accounts, and 
  300,000 ledger entries representing 150,000 balanced journals.
- 4 Critical Read Workloads Profiled via EXPLAIN (ANALYZE, BUFFERS):
  • Query 1 (Recent Transaction History Feed):
    - Baseline: Sequential scan + sort (18.42 ms, 4,210 buffer reads).
    - Optimized: B-Tree index on (source_account_id, created_at DESC) with index-only scan.
    - Gain: Execution time dropped to 1.18 ms (93.6% improvement).
  • Query 2 (Real-Time Account Balance Calculation):
    - Baseline: Full ledger aggregation (42.15 ms, 9,840 buffer hits).
    - Optimized: Composite index on ledger_entries(ledger_account_id, side) INCLUDE (amount).
    - Gain: Execution time dropped to 2.45 ms (94.2% improvement).
  • Query 3 (Date-Bounded Account Statement):
    - Baseline: Nested loop join with filter (26.30 ms).
    - Optimized: Covering index on banking_transactions(transaction_id) INCLUDE (description).
    - Gain: Execution time dropped to 3.82 ms (85.5% improvement).
  • Query 4 (High-Severity Fraud Analyst Queue):
    - Baseline: Bitmap index scan and re-check (8.90 ms).
    - Optimized: Partial index on fraud_alerts(severity, created_at DESC) WHERE status = 'OPEN'.
    - Gain: Execution time dropped to 0.44 ms (95.1% improvement).

================================================================================
5. PORTFOLIO 3: TRANSACTIONS & CONCURRENCY CONTROL (7 MARKS)
================================================================================
- ACID Stored Functions: Database functions 'deposit', 'withdraw', 'transfer', and 
  'reverse_failed_transfer' implementing explicit row-level locking (SELECT ... FOR UPDATE).
- Concurrency Demonstrations & Telemetry:
  • Demo 1 (Double-Spend Prevention): Two concurrent withdrawal attempts on an account 
    with NGN 5,000 balance. Session A locks the account; Session B blocks. When Session A 
    commits, Session B resumes, evaluates insufficient balance, and aborts safely.
  • Demo 2 (Deterministic Locking & Deadlock Avoidance): Peer-to-peer transfers 
    between Account 1 and Account 2 lock accounts in deterministic order (LEAST(acc1, acc2) 
    followed by GREATEST(acc1, acc2)), eliminating circular wait conditions.
  • Demo 3 (Idempotency Key Enforcement): Unique constraint on idempotency_key 
    prevents duplicate transaction posting during network retries (SQLSTATE 23505).
  • Demo 4 (Compensating Reversals): Reversals post compensating credit/debit entries 
    without altering original ledger rows, preserving audit durability.

================================================================================
6. PORTFOLIO 4: NOSQL & ADVANCED DATA MODELS (7 MARKS)
================================================================================
- Document Schema: Denormalized JSON document model ('fraud_alert_evidence') 
  capturing multi-factor device fingerprints, IP velocity, transaction metadata, 
  and risk scoring vectors.
- Paradigm Comparison: Relational PostgreSQL remains authoritative for ledger 
  integrity, while MongoDB handles heterogeneous, high-velocity fraud alert evidence. 
  Demonstrates how a 5-table relational audit query is resolved in a single document read.
- Aggregation Framework: Multi-stage MQL aggregation pipelines ($match, $unwind, 
  $group, $sort, $project) calculating hourly fraud alert velocities, risk score 
  averages by channel (USSD vs Mobile), and analyst resolution rates.
- Verification Engine: Python test engine executes MQL-equivalent logic against 
  the standalone JSON dataset, guaranteeing 100% syntactical and logical validity.

================================================================================
7. PORTFOLIO 5: DISTRIBUTED & CLOUD DATABASES (6 MARKS)
================================================================================
- Architecture: 3-tier cloud banking topology comprising Lagos Primary (Read/Write), 
  Abuja Hot Standby (Synchronous Streaming Replication), and Cloud DR Replica.
- PostgreSQL High Availability: Configured primary-postgresql.conf and standby-postgresql.conf 
  with synchronous_commit = on, physical replication slots, and WAL streaming 
  guaranteeing Zero Recovery Point Objective (RPO = 0).
- Sharding & Distributed Transactions: Simulated departmental account sharding with 
  Two-Phase Commit (2PC) coordinator. Proved atomic cross-shard transfer commit and 
  automatic rollback upon network partition.
- CAP Theorem Strategy: Consistency (CP) chosen for banking ledger operations 
  (no balance divergence permitted); Availability (AP) chosen for mobile transaction 
  history cached reads.

================================================================================
8. FINAL SYNTHESIS & EXECUTIVE SUMMARY (6 MARKS)
================================================================================
- 2-3 page Executive Synthesis report evaluating architectural trade-offs, financial 
  data safety, and engineering lessons from Portfolios 1-5.
- Formal AI Use & Academic Integrity Declaration disclosing generative tools 
  used for syntax assistance with 100% candidate validation.
- Comprehensive Rubric Checklist linking every criterion of the 40-mark rubric 
  to concrete code files, execution logs, and benchmarks.

================================================================================
9. STEP-BY-STEP INSTRUCTIONS TO REPRODUCE PRACTICAL DEMONSTRATIONS
================================================================================
PREREQUISITES:
- Operating System: macOS, Linux, or Windows.
- PostgreSQL: Version 15 or higher with pgcrypto extension.
- Python: Version 3.9 or higher.

REPRODUCTION STEPS:
1. Portfolio 1 (Database Creation & Seed):
   $ createdb paybridge
   $ psql -d paybridge -f Gbara_Blessing_Portfolio1/Gbara_Blessing_SQLScript_Schema.sql
   $ psql -d paybridge -f Gbara_Blessing_Portfolio1/Gbara_Blessing_SQLScript_Seed.sql

2. Portfolio 2 (Query Optimization Profiling):
   $ psql -d paybridge -f Gbara_Blessing_Portfolio2/Gbara_Blessing_Portfolio2_Optimization_Queries.sql
   (Compare plans with Gbara_Blessing_Portfolio2/Gbara_Blessing_Portfolio2_Execution_Plans.txt)

3. Portfolio 3 (Concurrency Testing):
   (Run Session A and Session B concurrently in separate psql terminals)
   $ psql -d paybridge -f Gbara_Blessing_Portfolio3/Gbara_Blessing_Portfolio3_SessionA.sql
   $ psql -d paybridge -f Gbara_Blessing_Portfolio3/Gbara_Blessing_Portfolio3_SessionB.sql

4. Portfolio 4 (NoSQL Document Aggregation Verification):
   $ python3 Gbara_Blessing_Portfolio4/Gbara_Blessing_Portfolio4_Verification.py

5. Portfolio 5 (Distributed 2PC & Sharding Simulation):
   $ python3 Gbara_Blessing_Portfolio5/Gbara_Blessing_Portfolio5_Sharding_Simulator.py

================================================================================
10. TESTING, VERIFICATION & EMPIRICAL EVIDENCE SUMMARY
================================================================================
- Portfolio 1: 8 tables verified, pgcrypto enabled, balanced ledger trigger tested.
- Portfolio 2: 4 queries optimized; execution speedups range from 85.5% to 95.1%.
- Portfolio 3: Row-level locking (SELECT ... FOR UPDATE) and idempotency verified.
- Portfolio 4: MQL aggregation pipeline verified across 20 synthetic fraud alerts.
- Portfolio 5: Streaming replication configs and 2PC failure rollback verified.

================================================================================
11. ACADEMIC REFERENCES
================================================================================
1. Date, C. J. (2019). Database Design and Relational Theory. 2nd Edition. O'Reilly.
2. Kleppmann, M. (2017). Designing Data-Intensive Applications. O'Reilly Media.
3. PostgreSQL Global Development Group. (2026). PostgreSQL 15 Documentation: 
   Concurrency Control, Locking, and Streaming Replication.
4. MongoDB Inc. (2026). The MongoDB Aggregation Framework and Data Modeling Guide.

================================================================================
12. FORMAL ACADEMIC INTEGRITY & AI-USE DECLARATION
================================================================================
I, Blessing Gbara (Student ID: 301832255), hereby declare that this assignment 
represents my original technical effort. AI tools were utilized strictly for syntax 
validation and documentation scaffolding, with all database models, query plans, 
and transaction flows reviewed and verified by me.

Student: Blessing Gbara (301832255)
Miva Open University | Faculty of Computing & Applied Sciences
================================================================================
