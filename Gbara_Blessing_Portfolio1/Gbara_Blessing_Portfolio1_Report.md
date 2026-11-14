# Portfolio 1: Relational Database Design and 3NF Modeling

**Student Name:** Blessing Gbara (Student ID: 301832255)  
**Course:** MIT 8103 – Advanced Database Systems  
**Institution:** Miva Open University  

## 1. Executive Summary
This portfolio delivers the foundational relational database design for **PayBridge**, a simulated Nigerian digital banking platform. The design is implemented in PostgreSQL 15+ using strict 3NF decomposition, UUID primary keys, and an append-only double-entry ledger.

## 2. Third Normal Form (3NF) Justification
1. **First Normal Form (1NF):** All attributes are atomic. Multi-valued fields (e.g., multiple accounts per customer, multiple ledger entries per transaction) are decomposed into child relations.
2. **Second Normal Form (2NF):** No partial dependencies exist. All non-key attributes are fully dependent on the primary keys. In `ledger_entries`, each entry depends entirely on `ledger_entry_id`.
3. **Third Normal Form (3NF):** No transitive dependencies exist. For example, customer details (name, email) are kept exclusively in `customers` and referenced via `customer_id` in `accounts`, preventing redundant data anomalies.

## 3. Double-Entry Invariants & Deferred Trigger
Financial transactions require mathematical balancing where total debits equal total credits. The trigger `fn_enforce_balanced_journal` is declared as:
```sql
CREATE CONSTRAINT TRIGGER trg_enforce_balanced_journal
AFTER INSERT OR UPDATE ON ledger_entries
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION fn_enforce_balanced_journal();
```
This ensures multi-leg postings can occur inside a single transaction, and the engine aborts the transaction at commit time if debits and credits do not balance.
