-- PayBridge PostgreSQL schema (PostgreSQL 15+)
-- Run in a new database with: psql -v ON_ERROR_STOP=1 -f schema.sql
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE kyc_status AS ENUM ('PENDING','IN_REVIEW','VERIFIED','REJECTED','EXPIRED');
CREATE TYPE account_status AS ENUM ('ACTIVE','FROZEN','CLOSED');
CREATE TYPE transaction_type AS ENUM ('DEPOSIT','WITHDRAWAL','TRANSFER','REVERSAL');
CREATE TYPE transaction_status AS ENUM ('PENDING','COMPLETED','FAILED','REVERSED');
CREATE TYPE ledger_side AS ENUM ('DEBIT','CREDIT');
CREATE TYPE account_class AS ENUM ('CUSTOMER','ASSET','LIABILITY','REVENUE','EXPENSE');
CREATE TYPE alert_status AS ENUM ('OPEN','INVESTIGATING','ESCALATED','RESOLVED','FALSE_POSITIVE');

CREATE TABLE customers (
  customer_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name text NOT NULL,
  last_name text NOT NULL,
  email text UNIQUE,
  phone_e164 text NOT NULL UNIQUE,
  date_of_birth date,
  bvn_token text UNIQUE, -- store a token/reference, never a raw BVN
  nin_token text UNIQUE, -- store a token/reference, never a raw NIN
  kyc_state kyc_status NOT NULL DEFAULT 'PENDING',
  kyc_reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (email IS NULL OR position('@' IN email) > 1)
);

CREATE TABLE app_users (
  user_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  user_role text NOT NULL CHECK (user_role IN ('CUSTOMER','SUPPORT','FRAUD_ANALYST','AUDITOR','PAYMENT_SERVICE','ADMIN')),
  customer_id uuid REFERENCES customers(customer_id),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((user_role = 'CUSTOMER') = (customer_id IS NOT NULL))
);

CREATE TABLE ledger_accounts (
  ledger_account_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_code text NOT NULL UNIQUE,
  account_name text NOT NULL,
  account_class account_class NOT NULL,
  currency char(3) NOT NULL DEFAULT 'NGN' CHECK (currency = 'NGN'),
  -- Balance is the account's normal balance; customer deposits have a credit-normal balance.
  balance numeric(20,2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Internal balancing accounts. Seeded once; all values are illustrative.
INSERT INTO ledger_accounts(account_code,account_name,account_class) VALUES
 ('SYS-CASH','Cash and settlement','ASSET'),
 ('SYS-TRANSFER-CLEARING','Transfer clearing','LIABILITY'),
 ('SYS-FEES','Fee income','REVENUE');

CREATE TABLE accounts (
  account_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES customers(customer_id),
  ledger_account_id uuid NOT NULL UNIQUE REFERENCES ledger_accounts(ledger_account_id),
  account_number char(10) NOT NULL UNIQUE CHECK (account_number ~ '^[0-9]{10}$'),
  account_type text NOT NULL CHECK (account_type IN ('SAVINGS','CURRENT','WALLET')),
  currency char(3) NOT NULL DEFAULT 'NGN' CHECK (currency = 'NGN'),
  status account_status NOT NULL DEFAULT 'ACTIVE',
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  CHECK ((status = 'CLOSED') = (closed_at IS NOT NULL))
);
CREATE INDEX accounts_customer_idx ON accounts(customer_id);
CREATE INDEX accounts_status_idx ON accounts(status);

CREATE TABLE banking_transactions (
  transaction_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_type transaction_type NOT NULL,
  status transaction_status NOT NULL DEFAULT 'PENDING',
  amount numeric(20,2) NOT NULL CHECK (amount > 0),
  currency char(3) NOT NULL DEFAULT 'NGN' CHECK (currency = 'NGN'),
  source_account_id uuid REFERENCES accounts(account_id),
  destination_account_id uuid REFERENCES accounts(account_id),
  external_reference text UNIQUE,
  idempotency_key text UNIQUE,
  related_transaction_id uuid REFERENCES banking_transactions(transaction_id),
  channel text NOT NULL DEFAULT 'SYSTEM' CHECK (channel IN ('MOBILE','WEB','USSD','BRANCH','SYSTEM','API')),
  initiated_by uuid REFERENCES app_users(user_id),
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  CHECK (source_account_id IS NULL OR destination_account_id IS NULL OR source_account_id <> destination_account_id),
  CHECK ((status = 'COMPLETED') = (completed_at IS NOT NULL))
);
CREATE INDEX transactions_source_time_idx ON banking_transactions(source_account_id,created_at DESC);
CREATE INDEX transactions_destination_time_idx ON banking_transactions(destination_account_id,created_at DESC);
CREATE INDEX transactions_status_time_idx ON banking_transactions(status,created_at DESC);

CREATE TABLE ledger_entries (
  ledger_entry_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  transaction_id uuid NOT NULL REFERENCES banking_transactions(transaction_id),
  ledger_account_id uuid NOT NULL REFERENCES ledger_accounts(ledger_account_id),
  side ledger_side NOT NULL,
  amount numeric(20,2) NOT NULL CHECK (amount > 0),
  currency char(3) NOT NULL DEFAULT 'NGN' CHECK (currency = 'NGN'),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ledger_transaction_idx ON ledger_entries(transaction_id);
CREATE INDEX ledger_account_time_idx ON ledger_entries(ledger_account_id,created_at DESC);

-- The ledger is append-only. Reversals are new, linked transactions; never edit history.
CREATE FUNCTION reject_ledger_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'ledger_entries are immutable; post a compensating transaction'; END $$;
CREATE TRIGGER ledger_no_update_delete BEFORE UPDATE OR DELETE ON ledger_entries
FOR EACH ROW EXECUTE FUNCTION reject_ledger_mutation();

-- Enforce double-entry balance after all rows for a journal have been written.
CREATE FUNCTION check_journal_balanced() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_debit numeric(20,2); v_credit numeric(20,2);
BEGIN
  SELECT COALESCE(sum(amount) FILTER (WHERE side='DEBIT'),0),
         COALESCE(sum(amount) FILTER (WHERE side='CREDIT'),0)
    INTO v_debit,v_credit FROM ledger_entries WHERE transaction_id=NEW.transaction_id;
  IF v_debit <> v_credit THEN
    RAISE EXCEPTION 'Unbalanced journal %: debit %, credit %', NEW.transaction_id,v_debit,v_credit;
  END IF;
  RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER ledger_journal_balanced AFTER INSERT ON ledger_entries
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION check_journal_balanced();

-- Account balance view is the source of truth; customer-account balances are credit-normal.
CREATE VIEW account_balances AS
SELECT a.account_id,a.account_number,a.customer_id,a.account_type,a.status,a.currency,
       COALESCE(sum(CASE WHEN le.side='CREDIT' THEN le.amount ELSE -le.amount END),0)::numeric(20,2) AS available_balance
FROM accounts a JOIN ledger_accounts la ON la.ledger_account_id=a.ledger_account_id
LEFT JOIN ledger_entries le ON le.ledger_account_id=la.ledger_account_id
GROUP BY a.account_id,a.account_number,a.customer_id,a.account_type,a.status,a.currency;

-- Create an account and its corresponding customer-liability ledger account.
CREATE FUNCTION open_account(p_customer uuid,p_account_number text,p_type text)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_account uuid; v_ledger uuid; v_code text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM customers WHERE customer_id=p_customer AND kyc_state='VERIFIED') THEN
    RAISE EXCEPTION 'Customer KYC must be VERIFIED before opening an account';
  END IF;
  IF p_type NOT IN ('SAVINGS','CURRENT','WALLET') OR p_account_number !~ '^[0-9]{10}$' THEN
    RAISE EXCEPTION 'Invalid account type or account number';
  END IF;
  v_account:=gen_random_uuid(); v_ledger:=gen_random_uuid();
  v_code:='CUST-'||replace(v_account::text,'-','');
  INSERT INTO ledger_accounts(ledger_account_id,account_code,account_name,account_class)
    VALUES(v_ledger,v_code,'Customer account '||p_account_number,'CUSTOMER');
  INSERT INTO accounts(account_id,customer_id,ledger_account_id,account_number,account_type)
    VALUES(v_account,p_customer,v_ledger,p_account_number,p_type);
  RETURN v_account;
END $$;

CREATE FUNCTION deposit(p_account uuid,p_amount numeric,p_reference text,p_actor uuid DEFAULT NULL,p_channel text DEFAULT 'API')
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_tx uuid:=gen_random_uuid(); v_customer_ledger uuid; v_cash uuid;
BEGIN
  IF p_amount<=0 OR round(p_amount,2)<>p_amount THEN RAISE EXCEPTION 'Amount must be positive with at most 2 decimals'; END IF;
  SELECT a.ledger_account_id INTO v_customer_ledger FROM accounts a WHERE a.account_id=p_account AND a.status='ACTIVE' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Active account not found'; END IF;
  SELECT ledger_account_id INTO v_cash FROM ledger_accounts WHERE account_code='SYS-CASH';
  INSERT INTO banking_transactions(transaction_id,transaction_type,status,amount,source_account_id,external_reference,idempotency_key,channel,initiated_by,completed_at)
  VALUES(v_tx,'DEPOSIT','COMPLETED',p_amount,p_account,p_reference,p_reference,p_channel,p_actor,now());
  INSERT INTO ledger_entries(transaction_id,ledger_account_id,side,amount) VALUES
   (v_tx,v_cash,'DEBIT',p_amount),(v_tx,v_customer_ledger,'CREDIT',p_amount);
  RETURN v_tx;
END $$;

CREATE FUNCTION withdraw(p_account uuid,p_amount numeric,p_reference text,p_actor uuid DEFAULT NULL,p_channel text DEFAULT 'API')
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_tx uuid:=gen_random_uuid(); v_customer_ledger uuid; v_cash uuid; v_balance numeric;
BEGIN
  IF p_amount<=0 OR round(p_amount,2)<>p_amount THEN RAISE EXCEPTION 'Amount must be positive with at most 2 decimals'; END IF;
  SELECT a.ledger_account_id INTO v_customer_ledger FROM accounts a WHERE a.account_id=p_account AND a.status='ACTIVE' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Active account not found'; END IF;
  SELECT available_balance INTO v_balance FROM account_balances WHERE account_id=p_account;
  IF v_balance<p_amount THEN RAISE EXCEPTION 'Insufficient funds'; END IF;
  SELECT ledger_account_id INTO v_cash FROM ledger_accounts WHERE account_code='SYS-CASH';
  INSERT INTO banking_transactions(transaction_id,transaction_type,status,amount,source_account_id,external_reference,idempotency_key,channel,initiated_by,completed_at)
  VALUES(v_tx,'WITHDRAWAL','COMPLETED',p_amount,p_account,p_reference,p_reference,p_channel,p_actor,now());
  INSERT INTO ledger_entries(transaction_id,ledger_account_id,side,amount) VALUES
   (v_tx,v_customer_ledger,'DEBIT',p_amount),(v_tx,v_cash,'CREDIT',p_amount);
  RETURN v_tx;
END $$;

CREATE FUNCTION transfer(p_source uuid,p_destination uuid,p_amount numeric,p_reference text,p_actor uuid DEFAULT NULL,p_channel text DEFAULT 'API')
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_tx uuid:=gen_random_uuid(); v_src_ledger uuid; v_dst_ledger uuid; v_balance numeric;
BEGIN
  IF p_source=p_destination THEN RAISE EXCEPTION 'Source and destination must differ'; END IF;
  IF p_amount<=0 OR round(p_amount,2)<>p_amount THEN RAISE EXCEPTION 'Amount must be positive with at most 2 decimals'; END IF;
  -- Lock both accounts in deterministic order to avoid transfer deadlocks.
  PERFORM 1 FROM accounts WHERE account_id IN (p_source,p_destination) ORDER BY account_id FOR UPDATE;
  SELECT ledger_account_id INTO v_src_ledger FROM accounts WHERE account_id=p_source AND status='ACTIVE';
  SELECT ledger_account_id INTO v_dst_ledger FROM accounts WHERE account_id=p_destination AND status='ACTIVE';
  IF v_src_ledger IS NULL OR v_dst_ledger IS NULL THEN RAISE EXCEPTION 'Both accounts must exist and be active'; END IF;
  SELECT available_balance INTO v_balance FROM account_balances WHERE account_id=p_source;
  IF v_balance<p_amount THEN RAISE EXCEPTION 'Insufficient funds'; END IF;
  INSERT INTO banking_transactions(transaction_id,transaction_type,status,amount,source_account_id,destination_account_id,external_reference,idempotency_key,channel,initiated_by,completed_at)
  VALUES(v_tx,'TRANSFER','COMPLETED',p_amount,p_source,p_destination,p_reference,p_reference,p_channel,p_actor,now());
  INSERT INTO ledger_entries(transaction_id,ledger_account_id,side,amount) VALUES
   (v_tx,v_src_ledger,'DEBIT',p_amount),(v_tx,v_dst_ledger,'CREDIT',p_amount);
  RETURN v_tx;
END $$;

-- Compensate a completed transfer with a new, balanced journal; original rows remain unchanged.
CREATE FUNCTION reverse_failed_transfer(p_original uuid,p_reference text,p_actor uuid DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_original banking_transactions%ROWTYPE; v_src uuid; v_dst uuid; v_reversal uuid:=gen_random_uuid();
BEGIN
  SELECT * INTO v_original FROM banking_transactions WHERE transaction_id=p_original FOR UPDATE;
  IF NOT FOUND OR v_original.transaction_type<>'TRANSFER' OR v_original.status<>'COMPLETED' THEN
    RAISE EXCEPTION 'Only a completed transfer can be reversed';
  END IF;
  IF EXISTS (SELECT 1 FROM banking_transactions WHERE related_transaction_id=p_original AND transaction_type='REVERSAL') THEN
    RAISE EXCEPTION 'Transfer has already been reversed';
  END IF;
  SELECT ledger_account_id INTO v_src FROM accounts WHERE account_id=v_original.source_account_id FOR UPDATE;
  SELECT ledger_account_id INTO v_dst FROM accounts WHERE account_id=v_original.destination_account_id FOR UPDATE;
  INSERT INTO banking_transactions(transaction_id,transaction_type,status,amount,source_account_id,destination_account_id,external_reference,idempotency_key,related_transaction_id,channel,initiated_by,completed_at,description)
  VALUES(v_reversal,'REVERSAL','COMPLETED',v_original.amount,v_original.destination_account_id,v_original.source_account_id,p_reference,p_reference,p_original,'SYSTEM',p_actor,now(),'Compensating reversal');
  INSERT INTO ledger_entries(transaction_id,ledger_account_id,side,amount) VALUES
   (v_reversal,v_dst,'DEBIT',v_original.amount),(v_reversal,v_src,'CREDIT',v_original.amount);
  UPDATE banking_transactions SET status='REVERSED' WHERE transaction_id=p_original;
  RETURN v_reversal;
END $$;

CREATE TABLE fraud_alerts (
  alert_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid REFERENCES customers(customer_id),
  account_id uuid REFERENCES accounts(account_id),
  transaction_id uuid REFERENCES banking_transactions(transaction_id),
  severity text NOT NULL CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
  rule_code text NOT NULL,
  description text NOT NULL,
  status alert_status NOT NULL DEFAULT 'OPEN',
  assigned_to uuid REFERENCES app_users(user_id),
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  CHECK ((status IN ('RESOLVED','FALSE_POSITIVE')) = (resolved_at IS NOT NULL))
);
CREATE INDEX fraud_alerts_open_idx ON fraud_alerts(status,severity,created_at DESC);

CREATE TABLE audit_log (
  audit_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_user_id uuid REFERENCES app_users(user_id),
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id text,
  old_values jsonb,
  new_values jsonb,
  request_id text,
  source_ip inet,
  occurred_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX audit_entity_time_idx ON audit_log(entity_type,entity_id,occurred_at DESC);
CREATE INDEX audit_time_idx ON audit_log(occurred_at DESC);

-- Record changes to sensitive operational tables. Ledger entries are already immutable.
CREATE FUNCTION audit_row_change() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_id text;
BEGIN
  v_id:=COALESCE(to_jsonb(NEW)->>TG_ARGV[0],to_jsonb(OLD)->>TG_ARGV[0]);
  INSERT INTO audit_log(actor_user_id,action,entity_type,entity_id,old_values,new_values)
  VALUES(NULL, TG_OP, TG_TABLE_NAME, v_id,
         CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) END,
         CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) END);
  RETURN COALESCE(NEW,OLD);
END $$;
CREATE TRIGGER audit_customers AFTER INSERT OR UPDATE OR DELETE ON customers FOR EACH ROW EXECUTE FUNCTION audit_row_change('customer_id');
CREATE TRIGGER audit_accounts AFTER INSERT OR UPDATE OR DELETE ON accounts FOR EACH ROW EXECUTE FUNCTION audit_row_change('account_id');
CREATE TRIGGER audit_transactions AFTER INSERT OR UPDATE OR DELETE ON banking_transactions FOR EACH ROW EXECUTE FUNCTION audit_row_change('transaction_id');
CREATE TRIGGER audit_alerts AFTER INSERT OR UPDATE OR DELETE ON fraud_alerts FOR EACH ROW EXECUTE FUNCTION audit_row_change('alert_id');

-- Statement query: SELECT * FROM account_statement('<account uuid>', timestamptz '2026-01-01', now());
CREATE FUNCTION account_statement(p_account uuid,p_from timestamptz,p_to timestamptz)
RETURNS TABLE(transaction_id uuid,posted_at timestamptz,transaction_type transaction_type,description text,debit numeric,credit numeric,running_balance numeric)
LANGUAGE sql STABLE AS $$
  SELECT t.transaction_id,t.created_at,t.transaction_type,t.description,
         CASE WHEN le.side='DEBIT' THEN le.amount ELSE 0 END,
         CASE WHEN le.side='CREDIT' THEN le.amount ELSE 0 END,
         sum(CASE WHEN le.side='CREDIT' THEN le.amount ELSE -le.amount END)
           OVER (ORDER BY t.created_at,t.transaction_id)::numeric(20,2)
  FROM accounts a JOIN ledger_entries le ON le.ledger_account_id=a.ledger_account_id
  JOIN banking_transactions t ON t.transaction_id=le.transaction_id
  WHERE a.account_id=p_account AND t.status IN ('COMPLETED','REVERSED') AND t.created_at>=p_from AND t.created_at<p_to
  ORDER BY t.created_at,t.transaction_id
$$;

-- Reconciliation query/view for auditors: customer cached balances are derived, never manually changed.
CREATE VIEW balance_audit AS
SELECT a.account_id,a.account_number,ab.available_balance,
       COALESCE(sum(CASE WHEN le.side='CREDIT' THEN le.amount ELSE -le.amount END),0)::numeric(20,2) AS ledger_balance,
       (ab.available_balance=COALESCE(sum(CASE WHEN le.side='CREDIT' THEN le.amount ELSE -le.amount END),0)) AS reconciles
FROM accounts a JOIN account_balances ab USING(account_id)
LEFT JOIN ledger_entries le ON le.ledger_account_id=a.ledger_account_id
GROUP BY a.account_id,a.account_number,ab.available_balance;

COMMIT;
