-- =====================================================================
-- 00_clean.sql  -  return the server to a fresh "week 1" state
-- Used by: labctl start-week N   (do not run by hand unless told to)
-- =====================================================================

DROP DATABASE IF EXISTS campusdb;

-- Accounts and roles created in labs 3 and 4
DROP USER IF EXISTS
  'efua_registry'@'localhost',
  'kofi_finance'@'localhost',
  'dr_asante'@'localhost',
  'portal_app'@'localhost',
  'backup_bot'@'localhost',
  'test'@'localhost';

DROP ROLE IF EXISTS role_registry, role_finance, role_lecturer;

-- Settings changed in lab 4
SET GLOBAL require_secure_transport = OFF;
RESET PERSIST IF EXISTS require_secure_transport;
