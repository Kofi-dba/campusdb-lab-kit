-- =====================================================================
-- 02_access_control.sql  -  CampusDB access control at the END of Lab 3
-- Roles, a lecturer view, and three staff accounts with password rules.
-- Requires 01_campusdb.sql first, and the validate_password component
-- (labctl installs it before running this file).
--
-- Library analogy: we stop handing out the master key and start issuing
-- library cards that only open the rooms each person's job needs.
-- =====================================================================

SET GLOBAL validate_password.policy = 'MEDIUM';
SET GLOBAL validate_password.length = 12;

CREATE ROLE IF NOT EXISTS role_registry, role_finance, role_lecturer;

GRANT SELECT, INSERT, UPDATE ON campusdb.students   TO role_registry;
GRANT SELECT, INSERT, UPDATE ON campusdb.enrolments TO role_registry;
GRANT SELECT                 ON campusdb.courses    TO role_registry;

GRANT SELECT, INSERT ON campusdb.fees     TO role_finance;
GRANT SELECT         ON campusdb.students TO role_finance;

CREATE OR REPLACE VIEW campusdb.v_lecturer_scores AS
  SELECT e.enrol_id, s.student_id, s.first_name, s.last_name, e.course_code, e.score
  FROM campusdb.students s
  JOIN campusdb.enrolments e ON s.student_id = e.student_id;

GRANT SELECT ON campusdb.v_lecturer_scores TO role_lecturer;
-- Column-level: lecturers may read enrol_id (so WHERE enrol_id = ... works)
-- and change only the score column.
GRANT SELECT (enrol_id), UPDATE (score) ON campusdb.enrolments TO role_lecturer;

CREATE USER IF NOT EXISTS 'efua_registry'@'localhost'
  IDENTIFIED BY 'Registry#Strong2026'
  PASSWORD EXPIRE INTERVAL 90 DAY FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 1;
CREATE USER IF NOT EXISTS 'kofi_finance'@'localhost'
  IDENTIFIED BY 'Finance#Strong2026'
  FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 1;
CREATE USER IF NOT EXISTS 'dr_asante'@'localhost'
  IDENTIFIED BY 'Lecturer#Strong2026'
  FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 1;

GRANT role_registry TO 'efua_registry'@'localhost';
GRANT role_finance  TO 'kofi_finance'@'localhost';
GRANT role_lecturer TO 'dr_asante'@'localhost';

SET DEFAULT ROLE ALL TO
  'efua_registry'@'localhost', 'kofi_finance'@'localhost', 'dr_asante'@'localhost';
