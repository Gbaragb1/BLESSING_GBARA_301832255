# Portfolio 3: Transactions and Concurrency Control Report

**Student:** Blessing Gbara (301832255)  
**Database:** PostgreSQL 15+  

## 1. Concurrency Controls Implemented
1. **Pessimistic Row-Level Locking:** All debit operations explicitly execute `SELECT ... FOR UPDATE` on the account entity, serializing operations per account.
2. **Deterministic Locking Sequence:** For peer-to-peer transfers, locks are acquired in sorted order:
   ```sql
   IF source_id < dest_id THEN
       PERFORM lock_account(source_id);
       PERFORM lock_account(dest_id);
   ELSE
       PERFORM lock_account(dest_id);
       PERFORM lock_account(source_id);
   END IF;
   ```
   This guarantees that opposing concurrent transfers (A->B and B->A) never deadlock.
3. **Idempotent Posting:** Every incoming payment request requires an `idempotency_key`, preventing duplicate ledger impacts during network retries.
