#!/usr/bin/env bash
# =====================================================================
# labctl - CampusDB lab helper
#
#   labctl help                 show this help
#   labctl doctor               check that MySQL is running and you can log in
#   labctl start-week N         reset your server to the START of week N (1-4)
#                               (use this if you missed a lab or broke something)
#   labctl check N              produce your evidence file for Lab N (1-4)
#   labctl snapshot             save a copy of campusdb into my-work/snapshots
#   labctl restore-snapshot     put back the most recent snapshot
#   labctl rootpw               update the root password labctl uses
#                               (run after you change root's password)
#
# Think of labctl as the library's caretaker: it can re-shelve the whole
# wing for you, but the real librarian work (SQL) is still yours to do.
# =====================================================================
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
SQL_DIR="$REPO_DIR/sql"
WORK_DIR="$REPO_DIR/my-work"
CONF="$HOME/.campusdb/root.cnf"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
ok()    { printf '\033[32m[ok]\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m[!!]\033[0m %s\n' "$*"; }
fail()  { printf '\033[31m[xx]\033[0m %s\n' "$*"; exit 1; }

# Run SQL as root using the protected credentials file.
m() { mysql --defaults-extra-file="$CONF" "$@"; }

ensure_running() {
  if ! sudo mysqladmin ping >/dev/null 2>&1; then
    warn "MySQL is not running - starting it..."
    bash "$REPO_DIR/.devcontainer/post-start.sh" || fail "MySQL would not start. Ask your lecturer (show them: sudo tail -n 30 /var/log/mysql/error.log)"
  fi
}

ensure_login() {
  [ -f "$CONF" ] || fail "Missing $CONF. Rebuild the codespace or ask your lecturer."
  if ! m -e "SELECT 1" >/dev/null 2>&1; then
    warn "labctl cannot log in as root - you probably changed root's password."
    set_rootpw
  fi
}

set_rootpw() {
  read -rsp "Enter the CURRENT MySQL root password: " pw; echo
  umask 077
  printf '[client]\nuser=root\npassword=%s\n' "$pw" > "$CONF"
  m -e "SELECT 1" >/dev/null 2>&1 && ok "Saved. labctl can log in again." || fail "That password did not work."
}

validate_pw_installed() {
  [ "$(m -N -e "SELECT COUNT(*) FROM mysql.component WHERE component_urn='file://component_validate_password'")" = "1" ]
}

cmd_doctor() {
  bold "CampusDB lab check-up"
  ensure_running; ok "MySQL server is running"
  ensure_login;   ok "Root login works"
  m -N -e "SELECT CONCAT('MySQL version: ', VERSION())"
  m -N -e "SELECT CONCAT('Databases: ', GROUP_CONCAT(schema_name)) FROM information_schema.schemata"
  if m -N -e "SELECT 1 FROM information_schema.schemata WHERE schema_name='campusdb'" | grep -q 1; then
    ok "campusdb exists"
  else
    warn "campusdb does not exist yet (normal before Lab 2)"
  fi
}

cmd_start_week() {
  local week="${1:-}"
  [[ "$week" =~ ^[1-4]$ ]] || fail "Usage: labctl start-week 1|2|3|4"
  ensure_running; ensure_login

  bold "This resets your MySQL server to the START of week $week."
  echo "Anything you built in campusdb and the lab users/roles will be replaced."
  if [ "${2:-}" != "-y" ]; then
    read -rp "Type YES to continue: " ans
    [ "$ans" = "YES" ] || { echo "Cancelled."; exit 0; }
  fi

  m < "$SQL_DIR/00_clean.sql" || fail "Clean-up failed"
  if validate_pw_installed; then
    m -e "UNINSTALL COMPONENT 'file://component_validate_password';" || warn "Could not remove password component"
  fi
  ok "Server cleaned (week 1 and week 2 start from here)"

  if [ "$week" -ge 3 ]; then
    m < "$SQL_DIR/01_campusdb.sql" || fail "Building campusdb failed"
    ok "campusdb built with tables, constraints and sample data (end of Lab 2)"
  fi
  if [ "$week" -ge 4 ]; then
    m -e "INSTALL COMPONENT 'file://component_validate_password';" || fail "Could not install password component"
    m < "$SQL_DIR/02_access_control.sql" || fail "Access control script failed"
    ok "Roles, lecturer view and staff accounts created (end of Lab 3)"
  fi
  bold "Ready for week $week. Open labs/lab$week-*.md"
}

cmd_snapshot() {
  ensure_running; ensure_login
  mkdir -p "$WORK_DIR/snapshots"
  local f="$WORK_DIR/snapshots/campusdb_$(date +%Y%m%d_%H%M%S).sql"
  mysqldump --defaults-extra-file="$CONF" --routines --triggers campusdb > "$f" \
    && ok "Snapshot saved: ${f#$REPO_DIR/}" \
    || fail "Snapshot failed (does campusdb exist?)"
  echo "Tip: commit and push my-work/ so the snapshot survives even a codespace rebuild."
}

cmd_restore_snapshot() {
  ensure_running; ensure_login
  local f
  f="$(ls -1t "$WORK_DIR"/snapshots/*.sql 2>/dev/null | head -1)"
  [ -n "$f" ] || fail "No snapshots found in my-work/snapshots"
  echo "Restoring ${f#$REPO_DIR/}"
  m -e "DROP DATABASE IF EXISTS campusdb; CREATE DATABASE campusdb;" && m campusdb < "$f" \
    && ok "Restored." || fail "Restore failed"
}

# ---------------------------------------------------------------------
# Evidence files: each one is stamped with your GitHub username, codespace
# name and time, so it can only have come from YOUR server.
# ---------------------------------------------------------------------
section() { printf '\n==== %s ====\n' "$*"; }
q()       { m -t -e "$1" 2>&1; }

cmd_check() {
  local lab="${1:-}"
  [[ "$lab" =~ ^[1-4]$ ]] || fail "Usage: labctl check 1|2|3|4"
  ensure_running; ensure_login
  mkdir -p "$WORK_DIR/evidence"
  local who="${GITHUB_USER:-$(whoami)}"
  local out="$WORK_DIR/evidence/lab${lab}_${who}.txt"
  local body; body="$(mktemp)"

  {
    echo "CampusDB evidence report - Lab $lab"
    echo "GitHub user : $who"
    echo "Codespace   : ${CODESPACE_NAME:-local}"
    echo "Generated   : $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    case "$lab" in
      1)
        section "Server version";   q "SELECT VERSION();"
        section "Databases";        q "SHOW DATABASES;"
        section "Accounts (who holds a library card)"
        q "SELECT user, host, plugin, account_locked FROM mysql.user ORDER BY user;"
        ;;
      2)
        section "Tables in campusdb"
        q "SELECT table_name, table_rows FROM information_schema.tables WHERE table_schema='campusdb' ORDER BY table_name;"
        section "Row counts (exact)"
        q "SELECT 'students' t, COUNT(*) n FROM campusdb.students UNION ALL
           SELECT 'courses', COUNT(*) FROM campusdb.courses UNION ALL
           SELECT 'enrolments', COUNT(*) FROM campusdb.enrolments UNION ALL
           SELECT 'fees', COUNT(*) FROM campusdb.fees;"
        section "Constraints (keys, unique, check, foreign keys)"
        q "SELECT table_name, constraint_name, constraint_type FROM information_schema.table_constraints
           WHERE table_schema='campusdb' ORDER BY table_name, constraint_type;"
        section "Foreign key relationships"
        q "SELECT table_name, column_name, referenced_table_name, referenced_column_name
           FROM information_schema.key_column_usage
           WHERE table_schema='campusdb' AND referenced_table_name IS NOT NULL;"
        section "Backup files in your workspace"
        find "$REPO_DIR" -maxdepth 2 \( -name '*backup*.sql' -o -name 'campusdb*.sql' \) -not -path '*/sql/*' -printf '%TY-%Tm-%Td %TH:%TM  %s bytes  %P\n' 2>/dev/null || true
        ;;
      3)
        section "Password policy"
        q "SHOW VARIABLES LIKE 'validate_password%';"
        section "Roles and users"
        q "SELECT user, host, account_locked, password_lifetime,
                  JSON_EXTRACT(user_attributes,'$.Password_locking') AS lockout
           FROM mysql.user WHERE user LIKE 'role_%' OR host='localhost'
           AND user NOT LIKE 'mysql.%' AND user NOT IN ('debian-sys-maint') ORDER BY user;"
        section "Who has which role"
        q "SELECT from_user AS role, to_user AS granted_to FROM mysql.role_edges ORDER BY from_user;"
        for u in efua_registry kofi_finance dr_asante; do
          section "SHOW GRANTS for $u"
          q "SHOW GRANTS FOR '$u'@'localhost' USING $(m -N -e "SELECT IFNULL(GROUP_CONCAT(from_user),'NONE') FROM mysql.role_edges WHERE to_user='$u'");" \
            || q "SHOW GRANTS FOR '$u'@'localhost';"
        done
        section "Lecturer view definition"
        q "SELECT table_name, LEFT(view_definition,200) AS starts_with FROM information_schema.views WHERE table_schema='campusdb';"
        ;;
      4)
        section "Encryption in transit"
        q "SHOW VARIABLES WHERE variable_name IN ('have_ssl','require_secure_transport','tls_version');"
        q "SELECT user, host, ssl_type FROM mysql.user WHERE user IN ('kofi_finance','portal_app');"
        section "Audit triggers on fees"
        q "SELECT trigger_name, action_timing, event_manipulation FROM information_schema.triggers WHERE event_object_table='fees';"
        section "Audit trail rows"
        q "SELECT * FROM campusdb.fees_audit ORDER BY audit_id;"
        section "Application account (least privilege)"
        q "SHOW GRANTS FOR 'portal_app'@'localhost';"
        section "Hardening: anonymous accounts / remote root / test DB"
        q "SELECT COUNT(*) AS anonymous_accounts FROM mysql.user WHERE user='';"
        q "SELECT COUNT(*) AS remote_root_accounts FROM mysql.user WHERE user='root' AND host NOT IN ('localhost','127.0.0.1','::1');"
        q "SELECT COUNT(*) AS test_database FROM information_schema.schemata WHERE schema_name='test';"
        q "SHOW VARIABLES LIKE 'bind_address';"
        section "Encrypted backup files"
        find "$REPO_DIR" -maxdepth 2 -name '*.enc' -printf '%TY-%Tm-%Td %TH:%TM  %s bytes  %P\n' 2>/dev/null || true
        ;;
    esac
  } > "$body"

  { cat "$body"; echo; echo "Integrity stamp: $(sha256sum "$body" | cut -c1-16)"; } > "$out"
  rm -f "$body"
  ok "Evidence written to ${out#$REPO_DIR/}"
  echo "Upload this file with your lab answers (right-click it in the Explorer > Download)."
}

case "${1:-help}" in
  doctor)            cmd_doctor ;;
  start-week)        cmd_start_week "${2:-}" "${3:-}" ;;
  check)             cmd_check "${2:-}" ;;
  snapshot)          cmd_snapshot ;;
  restore-snapshot)  cmd_restore_snapshot ;;
  rootpw)            ensure_running; set_rootpw ;;
  help|-h|--help|*)  sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
