# Portfolio 2: Query Processing and Index Optimization Report

**Student:** Blessing Gbara (301832255)  
**Database:** PostgreSQL 15+  

## Optimization Summary Matrix
| Query Workload | Baseline Time | Optimized Time | Speedup (%) | Buffer Reads Saved | Key Index Applied |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **Q1: Transaction Feed** | 18.49 ms | 1.18 ms | **93.6%** | 4,156 buffers | B-Tree `(source_account_id, created_at DESC)` |
| **Q2: Available Balance** | 42.21 ms | 2.45 ms | **94.2%** | 9,822 buffers | Index-Only Scan `(ledger_account_id, side)` |
| **Q3: Bounded Statement** | 26.30 ms | 3.82 ms | **85.5%** | 3,120 buffers | Composite Covering Index |
| **Q4: Fraud Alert Queue** | 8.90 ms | 0.44 ms | **95.1%** | 840 buffers | Partial Index `WHERE status='OPEN'` |

All query execution plans were captured using `EXPLAIN (ANALYZE, BUFFERS, SETTINGS)` on a 300,000-row ledger dataset.
