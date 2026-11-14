-- PayBridge Streaming Replication & Failover Management
-- Primary Node: Create Replication User & Physical Slot
CREATE ROLE rep_user WITH REPLICATION LOGIN ENCRYPTED PASSWORD 'SecretStandbyPass';
SELECT pg_create_physical_replication_slot('abuja_standby_slot');

-- Verify Replication Status on Primary
SELECT application_name, client_addr, state, sync_state, sync_priority 
FROM pg_stat_replication;

-- Failover Procedure: Promote Standby in Event of Disaster
-- Executed on Standby Node:
-- SELECT pg_promote();
