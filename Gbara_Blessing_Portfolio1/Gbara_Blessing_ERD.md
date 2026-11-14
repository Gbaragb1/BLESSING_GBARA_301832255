# PayBridge Digital Bank — Entity Relationship Diagram (ERD)

**Student Name:** Blessing Gbara (Student ID: 301832255)  
**Course:** MIT 8103 – Advanced Database Systems  
**Institution:** Miva Open University  

```mermaid
erDiagram
    CUSTOMERS ||--o{ ACCOUNTS : owns
    CUSTOMERS ||--o| APP_USERS : "may sign in as"
    ACCOUNTS ||--|| LEDGER_ACCOUNTS : maps_to
    LEDGER_ACCOUNTS ||--o{ LEDGER_ENTRIES : receives
    BANKING_TRANSACTIONS ||--|{ LEDGER_ENTRIES : posts
    BANKING_TRANSACTIONS o|--o| BANKING_TRANSACTIONS : reverses
    APP_USERS o|--o{ BANKING_TRANSACTIONS : initiates
    APP_USERS o|--o{ FRAUD_ALERTS : assigned_to
    CUSTOMERS o|--o{ FRAUD_ALERTS : concerns
    ACCOUNTS o|--o{ FRAUD_ALERTS : concerns
    BANKING_TRANSACTIONS o|--o{ FRAUD_ALERTS : triggers
    APP_USERS o|--o{ AUDIT_LOG : performs

    CUSTOMERS {
      uuid customer_id PK
      text first_name
      text last_name
      text email UK
      text phone_e164 UK
      text bvn_token UK
      text nin_token UK
      kyc_status kyc_state
    }
    APP_USERS {
      uuid user_id PK
      text username UK
      text password_hash
      text user_role
      uuid customer_id FK
      boolean is_active
    }
    ACCOUNTS {
      uuid account_id PK
      uuid customer_id FK
      uuid ledger_account_id FK_UK
      char account_number UK
      text account_type
      account_status status
      char currency
    }
    LEDGER_ACCOUNTS {
      uuid ledger_account_id PK
      text account_code UK
      text account_name
      account_class account_class
      numeric balance
    }
    BANKING_TRANSACTIONS {
      uuid transaction_id PK
      transaction_type transaction_type
      transaction_status status
      numeric amount
      uuid source_account_id FK
      uuid destination_account_id FK
      text external_reference UK
      text idempotency_key UK
    }
    LEDGER_ENTRIES {
      bigint ledger_entry_id PK
      uuid transaction_id FK
      uuid ledger_account_id FK
      ledger_side side
      numeric amount
      timestamptz created_at
    }
    FRAUD_ALERTS {
      uuid alert_id PK
      uuid customer_id FK
      uuid account_id FK
      uuid transaction_id FK
      alert_status status
      text severity
      text rule_code
    }
    AUDIT_LOG {
      bigint audit_id PK
      uuid user_id FK
      text action
      text entity_name
      timestamptz executed_at
    }
```

## Data Dictionary Overview
- **CUSTOMERS:** Stores consumer KYC references. BVN and NIN values are securely tokenized per NDPR regulations.
- **ACCOUNTS:** Customer-facing account identifiers with 10-digit NUBAN compliance.
- **LEDGER_ACCOUNTS & LEDGER_ENTRIES:** Strict double-entry append-only accounting journal.
- **BANKING_TRANSACTIONS:** Financial operation intent with unique idempotency keys.
- **FRAUD_ALERTS & AUDIT_LOG:** Regulatory compliance and risk management records.
