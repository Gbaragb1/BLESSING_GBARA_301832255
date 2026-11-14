# PayBridge Digital Bank: Executive Synthesis Report
## MIT 8103 – Advanced Database Systems (Continuous Assessment)

**Student Name:** Blessing Gbara  
**Student ID:** 301832255  
**Course:** MIT 8103 – Advanced Database Systems  
**Institution:** Miva Open University  
**Date:** November 2026  

---

### 1. Architectural Vision and Engineering Context
The modern digital banking landscape demands absolute transactional accuracy paired with ultra-low latency customer interactions. The **PayBridge** platform was engineered to satisfy these dual requirements for Nigeria's expanding fintech ecosystem. 

Rather than adopting a monolithic or single-paradigm database, PayBridge implements a **polyglot persistence and multi-tier data architecture**:
1. **Relational Core (PostgreSQL 15+):** Governs retail customer accounts, KYC status, and an append-only double-entry general ledger.
2. **Pessimistic Concurrency Engine:** Implements row-level locking (`SELECT ... FOR UPDATE`) and deterministic lock sequencing, guaranteeing that customer balances can never be overdrawn or double-spent.
3. **NoSQL Document Projection (MongoDB):** Handles high-volume fraud detection telemetry and multi-channel risk scoring.
4. **Distributed High Availability:** Employs synchronous streaming replication with Zero Data Loss ($RPO = 0$) and a simulated Two-Phase Commit (2PC) coordinator.

---

### 2. Synthesis of Portfolio Achievements

#### Portfolio 1: Relational Modeling & Financial Accounting Invariants
PayBridge models 8 core relational entities normalized strictly to Third Normal Form (3NF). Financial integrity is preserved through an append-only ledger where every deposit, withdrawal, or transfer consists of balanced credit and debit entries. A deferred constraint trigger (`trg_enforce_balanced_journal`) validates debit/credit equality at transaction commit, preventing single-sided ledger corruption.

#### Portfolio 2: Query Processing & Index Optimization
On a benchmark dataset of 2,000 customers, 2,666 accounts, and 300,000 ledger entries, query execution plans were profiled using `EXPLAIN (ANALYZE, BUFFERS)`. By introducing targeted B-Tree composite and partial indexes, execution times across 4 critical workloads were improved by **85.5% to 95.1%**, while eliminating expensive full-table sequential scans.

#### Portfolio 3: Transactions & Concurrency Control
Using PostgreSQL stored functions and dual-session testing harnesses, the system verified that concurrent withdrawal attempts on identical accounts are serialized safely. Opposing peer-to-peer transfers utilize sorted account ID locking, completely eliminating deadlocks. Network retry idempotency was validated via unique key enforcement.

#### Portfolio 4: NoSQL Document Models & Aggregation
Analyzing fraud evidence revealed that relational joins across 5 tables create unnecessary query overhead during time-critical fraud investigations. Projecting fraud evidence into denormalized JSON documents allowed investigators to retrieve complete alert packages in a single disk read ($O(1)$). Multi-stage MQL pipelines demonstrated real-time risk aggregation across Mobile, Web, and USSD channels.

#### Portfolio 5: Distributed Architectures & Fault Tolerance
A multi-region streaming replication architecture was specified (Lagos Primary to Abuja Synchronous Standby). The trade-offs of Brewer's CAP theorem were explicitly navigated: CP was chosen for the authoritative financial ledger, while AP was adopted for non-critical statement reads. A Two-Phase Commit simulator proved that network partitions trigger coordinated aborts, preserving balance consistency across distributed shards.

---

### 3. Conclusion & Key Engineering Reflections
The PayBridge implementation proves that enterprise financial platforms cannot rely on basic CRUD operations or unverified application logic. Data integrity must be enforced at the database engine level through constraints, triggers, and deterministic locking protocols. Through systematic indexing, polyglot document modeling, and distributed replication, PayBridge delivers a secure, high-performance database system fully aligned with the requirements of Miva Open University's MIT 8103 curriculum.
