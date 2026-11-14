# Portfolio 4: NoSQL and Advanced Data Models Report

**Student:** Blessing Gbara (301832255)  
**Paradigms Evaluated:** Relational (PostgreSQL) vs Document (MongoDB)  

## 1. Paradigm Justification for Financial Fraud Detection
While PostgreSQL remains the immutable source of truth for the financial ledger (requiring strict ACID guarantees), fraud investigation telemetry involves highly heterogeneous, nested, and time-sensitive metadata (device risk metrics, IP geolocations, behavioral velocity counters). 

Modeling fraud evidence in MongoDB eliminates costly 5-table joins across accounts, customers, transactions, and audit records, allowing investigators to fetch complete alert contexts in a single document read ($O(1)$).

## 2. Multi-Stage Aggregation Pipelines
Document pipelines aggregate velocity alerts across multiple channels (USSD, Mobile, Web) in real-time without locking the transactional database.
