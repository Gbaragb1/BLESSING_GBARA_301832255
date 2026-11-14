# Portfolio 5: Distributed and Cloud Databases Report

**Student:** Blessing Gbara (301832255)  
**Database:** PostgreSQL 15+ Streaming Replication & Distributed Architectures  

## 1. High-Availability Multi-Campus Topology
PayBridge adopts a multi-region deployment across Nigeria:
- **Lagos Main Region (Primary):** Serves all transactional financial writes.
- **Abuja Region (Synchronous Hot Standby):** Replicated via synchronous streaming replication, ensuring Zero Recovery Point Objective ($RPO = 0$).
- **Cloud Disaster Recovery (DR):** Asynchronous read-only replica for analytics and cold failover.

## 2. CAP Theorem Strategic Evaluation
In accordance with Brewer's CAP theorem, network partitions ($P$) are inevitable in wide-area banking networks. PayBridge enforces:
- **CP (Consistency + Partition Tolerance) for Money Movements:** In the event of a network split between Lagos and Abuja, the system rejects unconfirmed writes rather than allowing duplicate spending.
- **AP (Availability + Partition Tolerance) for Portal Inquiries:** Account history and cached statements remain readable from regional replicas even during transient network degradation.
