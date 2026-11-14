# Portfolio 1: Database Deployment and Constraint Testing Report

**Student:** Blessing Gbara (301832255)  
**Database:** PostgreSQL 15+ (Engine verification)  

## Table Deployment Matrix
| Table Name | Primary Key | Total Constraints | Verified Rows | Integrity Status |
| :--- | :--- | :---: | :---: | :---: |
| `customers` | `customer_id` (UUID) | 6 (UK, Check) | 2,000 | **PASS** |
| `app_users` | `user_id` (UUID) | 4 (FK, Check) | 2,050 | **PASS** |
| `ledger_accounts` | `ledger_account_id` (UUID) | 3 (UK, Check) | 2,669 | **PASS** |
| `accounts` | `account_id` (UUID) | 5 (FK, Check) | 2,666 | **PASS** |
| `banking_transactions` | `transaction_id` (UUID) | 7 (FK, UK, Check) | 150,000 | **PASS** |
| `ledger_entries` | `ledger_entry_id` (BIGINT) | 4 (FK, Check) | 300,000 | **PASS** |
| `fraud_alerts` | `alert_id` (UUID) | 4 (FK, Check) | 1,240 | **PASS** |
| `audit_log` | `audit_id` (BIGINT) | 2 (FK) | 8,500 | **PASS** |

## Negative Constraint Test Execution
1. **Invalid Account Number Format:** Insertion of 9-digit account `'123456789'` fails check constraint `accounts_account_number_check` (`ERROR: 23514`).
2. **Negative Transaction Amount:** Inserting amount `-500.00` fails `banking_transactions_amount_check` (`ERROR: 23514`).
3. **Unbalanced Journal Commit:** Posting single-sided debit of NGN 10,000 without balancing credit fails `trg_enforce_balanced_journal` (`ERROR: P0001: Journal does not balance`).
