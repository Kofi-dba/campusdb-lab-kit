-- =====================================================================
-- 00_clean.sql  -  return the server to a completely fresh state
-- Used by: labctl start-lab N   (do not run by hand unless told to)
-- =====================================================================

-- Databases created by labctl or by students in labs 1-10
DROP DATABASE IF EXISTS campusdb;
DROP DATABASE IF EXISTS sheet_demo;
DROP DATABASE IF EXISTS campus_preview;
DROP DATABASE IF EXISTS sandbox;
DROP DATABASE IF EXISTS exam_w2;

-- Accounts and roles created in the week 3-4 labs
DROP USER IF EXISTS
  'efua_registry'@'localhost',
  'kofi_finance'@'localhost',
  'dr_asante'@'localhost',
  'portal_app'@'localhost',
  'backup_bot'@'localhost',
  'test'@'localhost';

DROP ROLE IF EXISTS role_registry, role_finance, role_lecturer;

-- Settings changed in the week 4 lab
SET GLOBAL require_secure_transport = OFF;
RESET PERSIST IF EXISTS require_secure_transport;
