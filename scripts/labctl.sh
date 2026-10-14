#!/usr/bin/env bash
# =====================================================================
# labctl - CampusDB lab helper
#
#   labctl help              show this help
#   labctl doctor            check that MySQL is running and you can log in
#   labctl hello [N]         sign the attendance book (do this at the START of every lab)
#   labctl start-lab N       reset your server to the START of lab N (1-10)
#                            (use it if you missed a lab or broke something)
#   labctl check N           write your evidence file for lab N
#   labctl submit N          check N + save my-work to GitHub (do this at the END of every lab)
#   labctl restart           restart MySQL safely (used in lab 8)
#   labctl snapshot          save a copy of campusdb into my-work/snapshots
#   labctl restore-snapshot  put back the most recent snapshot
#   labctl update            download the newest lab sheets from your lecturer
#   labctl rootpw            tell labctl the new root password (after you change it)
#
# Think of labctl as the library's caretaker: it can re-shelve the whole
# wing for you, but the real librarian work (SQL) is still yours to do.
# =====================================================================
set -uo pipefail

# The lecturer's template repository (where `labctl update` gets new sheets)
TEMPLATE_REPO="Kofi-dba/campusdb-lab-kit"

REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
SQL_DIR="$REPO_DIR/sql"
WORK_DIR="$REPO_DIR/my-work"
CONF="$HOME/.campusdb/root.cnf"
WHO="${GITHUB_USER:-$(whoami)}"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
ok()    { printf '\033[32m[ok]\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m[!!]\033[0m %s\n' "$*"; }
fail()  { printf '\033[31m[xx]\033[0m %s\n' "$*"; exit 1; }

# Run SQL as root using the protected credentials file.
m() { mysql --defaults-extra-file="$CONF" "$@"; }

open_socket_door() { sudo chmod 755 /var/run/mysqld 2>/dev/null || true; }

ensure_running() {
  if ! sudo mysqladmin ping >/dev/null 2>&1; then
    warn "MySQL is not running - starting it..."
    bash "$REPO_DIR/.devcontainer/post-start.sh" || fail "MySQL would not start. Ask your lecturer (show them: sudo tail -n 30 /var/log/mysql/error.log)"
  fi
  open_socket_door
}

ensure_login() {
  [ -f "$CONF" ] || fail "Missing $CONF. Run: bash .devcontainer/post-create.sh"
  local err; err="$(m -e "SELECT 1" 2>&1 >/dev/null)"
  if [ -n "$err" ]; then
    if echo "$err" | grep -q "ERROR 2002"; then
      fail "Cannot reach the MySQL socket: $err"
    fi
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

db_exists() { m -N -e "SELECT 1 FROM information_schema.schemata WHERE schema_name='$1'" | grep -q 1; }

# ---------------------------------------------------------------------
# doctor / restart
# ---------------------------------------------------------------------
cmd_doctor() {
  bold "CampusDB lab check-up"
  ensure_running; ok "MySQL server is running"
  ensure_login;   ok "Root login works"
  m -N -e "SELECT CONCAT('MySQL version: ', VERSION())"
  m -N -e "SELECT CONCAT('Databases: ', GROUP_CONCAT(schema_name)) FROM information_schema.schemata"
  if git -C "$REPO_DIR" remote get-url origin >/dev/null 2>&1; then
    ok "Linked to GitHub repo: $(git -C "$REPO_DIR" remote get-url origin | sed 's#https://github.com/##; s#\.git$##')"
  else
    warn "This codespace is NOT linked to your own repository - 'labctl submit' cannot save to GitHub."
    echo "     Fix: create your repo from the template first (see labs/00-getting-started.md)."
  fi
}

cmd_restart() {
  bold "Restarting MySQL (like switching the library off and on again)..."
  sudo service mysql restart >/dev/null 2>&1 || bash "$REPO_DIR/.devcontainer/post-start.sh"
  for i in $(seq 1 30); do sudo mysqladmin ping >/dev/null 2>&1 && break; sleep 1; done
  open_socket_door
  sudo mysqladmin ping >/dev/null 2>&1 && ok "MySQL is back up" || fail "MySQL did not come back. Run: labctl doctor"
}

# ---------------------------------------------------------------------
# start-lab N : put the server in the state lab N expects
#   lab 1        : empty server
#   labs 2 - 7   : + week 1 sample databases (sheet_demo, campus_preview)
#   labs 8 - 10  : + campusdb as built in lab 7, with sample data
# ---------------------------------------------------------------------
copy_answer_sheet() {
  local n="$1" src="$REPO_DIR/labs/answer-sheets/lab$(printf '%02d' "$1")-answers.md"
  local dst="$WORK_DIR/lab$(printf '%02d' "$1")-answers.md"
  mkdir -p "$WORK_DIR"
  if [ -f "$src" ] && [ ! -f "$dst" ]; then
    cp "$src" "$dst"; ok "Your answer sheet is ready: my-work/$(basename "$dst")"
  elif [ -f "$dst" ]; then
    ok "Your answer sheet already exists (kept): my-work/$(basename "$dst")"
  fi
}

cmd_start_lab() {
  local lab="${1:-}"
  [[ "$lab" =~ ^([1-9]|10)$ ]] || fail "Usage: labctl start-lab 1..10"
  ensure_running; ensure_login

  bold "This resets your MySQL server to the START of lab $lab."
  echo "Lab databases (campusdb, sheet_demo, campus_preview, sandbox, exam_w2) will be replaced."
  echo "Your files in my-work/ are NOT touched."
  if [ "${2:-}" != "-y" ]; then
    read -rp "Type YES to continue: " ans
    [ "$ans" = "YES" ] || { echo "Cancelled."; exit 0; }
  fi

  m < "$SQL_DIR/00_clean.sql" || fail "Clean-up failed"
  if validate_pw_installed; then
    m -e "UNINSTALL COMPONENT 'file://component_validate_password';" >/dev/null 2>&1 || true
  fi
  ok "Server cleaned"

  if [ "$lab" -ge 2 ]; then
    m < "$SQL_DIR/w1_samples.sql" || fail "Loading sample databases failed"
    ok "Week 1 sample databases loaded (sheet_demo, campus_preview)"
  fi
  if [ "$lab" -ge 8 ]; then
    m < "$SQL_DIR/01_campusdb.sql" || fail "Building campusdb failed"
    ok "campusdb built with tables, constraints and sample data (end of lab 7)"
  fi
  if [ "$lab" = "5" ] || [ "$lab" = "10" ]; then copy_answer_sheet "$lab"; fi
  bold "Ready for lab $lab. Open labs/lab$(printf '%02d' "$lab")-*.md"
}

# Kept for the week 3-4 labs (labs/later/)
cmd_start_week() {
  local week="${1:-}"
  [[ "$week" =~ ^[34]$ ]] || fail "For weeks 1-2 use: labctl start-lab 1..10"
  ensure_running; ensure_login
  read -rp "Reset the server to the start of week $week? Type YES: " ans
  [ "$ans" = "YES" ] || { echo "Cancelled."; exit 0; }
  m < "$SQL_DIR/00_clean.sql" || fail "Clean-up failed"
  validate_pw_installed && m -e "UNINSTALL COMPONENT 'file://component_validate_password';" >/dev/null 2>&1
  m < "$SQL_DIR/01_campusdb.sql" || fail "Building campusdb failed"
  ok "campusdb built"
  if [ "$week" = "4" ]; then
    m -e "INSTALL COMPONENT 'file://component_validate_password';" || fail "Could not install password component"
    m < "$SQL_DIR/02_access_control.sql" || fail "Access control script failed"
    ok "Roles, lecturer view and staff accounts created"
  fi
  bold "Ready for week $week."
}

# ---------------------------------------------------------------------
# snapshots
# ---------------------------------------------------------------------
cmd_snapshot() {
  ensure_running; ensure_login
  mkdir -p "$WORK_DIR/snapshots"
  local f="$WORK_DIR/snapshots/campusdb_$(date +%Y%m%d_%H%M%S).sql"
  mysqldump --defaults-extra-file="$CONF" --single-transaction --routines --triggers campusdb > "$f" \
    && ok "Snapshot saved: ${f#$REPO_DIR/}" \
    || fail "Snapshot failed (does campusdb exist?)"
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
# GitHub: attendance and submissions
# ---------------------------------------------------------------------
git_save() {   # git_save "message"
  local msg="$1"
  if ! git -C "$REPO_DIR" remote get-url origin >/dev/null 2>&1; then
    warn "Not linked to your GitHub repo, so nothing was uploaded."
    echo "     Download the files in my-work/ and upload them to the course page instead."
    return 1
  fi
  git -C "$REPO_DIR" add my-work >/dev/null 2>&1
  git -C "$REPO_DIR" commit -q -m "$msg" >/dev/null 2>&1 || true
  git -C "$REPO_DIR" pull -q --rebase --autostash >/dev/null 2>&1 || true
  if git -C "$REPO_DIR" push -q >/dev/null 2>&1; then
    ok "Saved to GitHub ($msg)"
  else
    warn "Could not upload to GitHub. Your files are still safe in my-work/. Try again: labctl submit"
    return 1
  fi
}

cmd_hello() {
  local lab="${1:-}"
  mkdir -p "$WORK_DIR"
  local line
  line="$(date -u '+%Y-%m-%d %H:%M UTC')  hello  user=$WHO  lab=${lab:--}  codespace=${CODESPACE_NAME:-local}"
  echo "$line" >> "$WORK_DIR/attendance.log"
  ok "Signed in: $line"
  git_save "Attendance: lab ${lab:--}" || true
}

cmd_submit() {
  local lab="${1:-}"
  [[ "$lab" =~ ^([1-9]|10)$ ]] || fail "Usage: labctl submit 1..10"
  cmd_check "$lab"
  echo "$(date -u '+%Y-%m-%d %H:%M UTC')  submit user=$WHO  lab=$lab" >> "$WORK_DIR/attendance.log"
  git_save "Lab $lab submission"
}

# ---------------------------------------------------------------------
# update: fetch the newest lab sheets/scripts from the lecturer's template
# ---------------------------------------------------------------------
cmd_update() {
  local tmp; tmp="$(mktemp -d)"
  bold "Downloading the newest labs from $TEMPLATE_REPO ..."
  curl -fsSL "https://codeload.github.com/$TEMPLATE_REPO/tar.gz/refs/heads/main" -o "$tmp/kit.tgz" \
    || fail "Download failed. Check your internet connection and try again."
  tar -xzf "$tmp/kit.tgz" -C "$tmp" || fail "Could not unpack the download."
  local src; src="$(find "$tmp" -maxdepth 1 -mindepth 1 -type d | head -1)"
  for d in labs scripts sql demo; do
    [ -d "$src/$d" ] || continue
    rm -rf "${REPO_DIR:?}/$d"
    cp -r "$src/$d" "$REPO_DIR/$d"
  done
  chmod +x "$REPO_DIR"/scripts/*.sh "$REPO_DIR"/demo/*.py 2>/dev/null || true
  rm -rf "$tmp"
  ok "Lab sheets and scripts updated. Your my-work/ folder was not touched."
  git -C "$REPO_DIR" add labs scripts sql demo >/dev/null 2>&1
  git -C "$REPO_DIR" commit -q -m "Update labs from lecturer template" >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------
# Evidence files: stamped with your GitHub username, codespace name and
# time, so they can only have come from YOUR server.
# ---------------------------------------------------------------------
section() { printf '\n==== %s ====\n' "$*"; }
q()       { m -t -e "$1" 2>&1; }

recent_history() {   # the SQL you typed (the mysql client saves it when you type exit)
  section "Your recent SQL commands (from ~/.mysql_history)"
  if [ -f "$HOME/.mysql_history" ]; then
    tail -n "${1:-40}" "$HOME/.mysql_history" | sed 's/\\040/ /g; s/\\011/ /g'
  else
    echo "(no history yet - it is saved when you type exit in the mysql client)"
  fi
}

list_files() {   # list_files PATTERN...
  local p
  for p in "$@"; do
    find "$WORK_DIR" -maxdepth 2 -name "$p" -printf '%TY-%Tm-%Td %TH:%TM  %8s bytes  my-work/%P\n' 2>/dev/null
  done | sort -u
}

answer_sheet_status() {
  local f="$WORK_DIR/lab$(printf '%02d' "$1")-answers.md"
  section "Answer sheet"
  if [ -f "$f" ]; then
    echo "my-work/$(basename "$f"): $(grep -cE '^>\s*[^[:space:]]' "$f") answered, last saved $(date -u -r "$f" '+%Y-%m-%d %H:%M UTC')"
  else
    echo "MISSING: run  labctl start-lab $1  (it copies the answer sheet into my-work/)"
  fi
}

# --- auto-marking for the lab 10 practical questions -----------------
PASS=0; TOTAL=0
mark() {   # mark "Qn description" <0|1>
  TOTAL=$((TOTAL+1))
  if [ "$2" = "1" ]; then PASS=$((PASS+1)); echo "  [PASS] $1"; else echo "  [----] $1"; fi
}
v() { m -N -e "$1" 2>/dev/null | head -1; }   # single value

exam_w2_marks() {
  section "Part B auto-marking (questions 13-19; question 20 is marked by your lecturer)"
  local dbx tc
  dbx="$(v "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='exam_w2'")"
  mark "Q13 database exam_w2 exists" "$([ "$dbx" = "1" ] && echo 1 || echo 0)"

  tc="$(v "SELECT COUNT(DISTINCT constraint_type) FROM information_schema.table_constraints
          WHERE table_schema='exam_w2' AND table_name='books'
          AND constraint_type IN ('PRIMARY KEY','UNIQUE','CHECK')")"
  local nn df
  nn="$(v "SELECT is_nullable FROM information_schema.columns WHERE table_schema='exam_w2' AND table_name='books' AND column_name='title'")"
  df="$(v "SELECT column_default FROM information_schema.columns WHERE table_schema='exam_w2' AND table_name='books' AND column_name='copies'")"
  mark "Q14 books has PRIMARY KEY + UNIQUE + CHECK, title NOT NULL, copies DEFAULT 1" \
       "$([ "$tc" = "3" ] && [ "$nn" = "NO" ] && [ "$df" = "1" ] && echo 1 || echo 0)"

  local ai fk
  ai="$(v "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='exam_w2' AND table_name='loans' AND column_name='loan_id' AND column_key='PRI' AND extra LIKE '%auto_increment%'")"
  fk="$(v "SELECT COUNT(*) FROM information_schema.key_column_usage WHERE table_schema='exam_w2' AND table_name='loans' AND column_name='book_id' AND referenced_table_name='books' AND referenced_column_name='book_id'")"
  mark "Q15 loans has AUTO_INCREMENT primary key loan_id and a FOREIGN KEY book_id -> books" \
       "$([ "$ai" = "1" ] && [ "$fk" = "1" ] && echo 1 || echo 0)"

  local nb nl
  nb="$(v "SELECT COUNT(*) FROM exam_w2.books")"; nl="$(v "SELECT COUNT(*) FROM exam_w2.loans")"
  mark "Q16 at least 3 books and 2 loans inserted (found ${nb:-0} books, ${nl:-0} loans)" \
       "$([ "${nb:-0}" -ge 3 ] && [ "${nl:-0}" -ge 2 ] && echo 1 || echo 0)"

  local ak c2
  ak="$(v "SELECT COUNT(*) FROM exam_w2.loans WHERE borrower='Akosua Darko' AND book_id=2")"
  c2="$(v "SELECT copies FROM exam_w2.books WHERE book_id=2")"
  mark "Q17 transaction: loan for Akosua Darko on book 2 AND book 2 copies reduced from 3 to 2" \
       "$([ "${ak:-0}" -ge 1 ] && [ "$c2" = "2" ] && echo 1 || echo 0)"

  local bf="$WORK_DIR/exam_w2_backup.sql" bok=0
  if [ -f "$bf" ] && grep -q 'CREATE TABLE `loans`' "$bf" && grep -q 'INSERT INTO `books`' "$bf"; then bok=1; fi
  mark "Q18 backup my-work/exam_w2_backup.sql contains both tables and their data" "$bok"

  local sf="$WORK_DIR/exam_w2_backup.sha256" sok=0
  if [ -f "$sf" ] && [ -f "$bf" ] && (cd "$WORK_DIR" && sha256sum -c "$(basename "$sf")" >/dev/null 2>&1); then sok=1; fi
  mark "Q19 checksum my-work/exam_w2_backup.sha256 exists and matches the backup" "$sok"

  echo
  echo "  Auto-marked practical score: $PASS / $TOTAL"
}

cmd_check() {
  local lab="${1:-}"
  [[ "$lab" =~ ^([1-9]|10)$ ]] || fail "Usage: labctl check 1..10"
  ensure_running; ensure_login
  mkdir -p "$WORK_DIR/evidence"
  local out="$WORK_DIR/evidence/lab$(printf '%02d' "$lab")_${WHO}.txt"
  local body; body="$(mktemp)"

  {
    echo "CampusDB evidence report - Lab $lab"
    echo "GitHub user : $WHO"
    echo "Codespace   : ${CODESPACE_NAME:-local}"
    echo "Generated   : $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    case "$lab" in
      1)
        section "Server version";   q "SELECT VERSION();"
        section "Databases";        q "SHOW DATABASES;"
        section "Accounts (who holds a library card)"
        q "SELECT user, host, plugin, account_locked FROM mysql.user ORDER BY user;"
        recent_history 30 ;;
      2)
        section "sheet_demo still present (should be 9 rows)"
        q "SELECT COUNT(*) AS rows_in_sheet FROM sheet_demo.results_sheet;"
        section "campus_preview row counts"
        q "SELECT 'students' t, COUNT(*) n FROM campus_preview.students UNION ALL
           SELECT 'enrolments', COUNT(*) FROM campus_preview.enrolments;"
        recent_history 50 ;;
      3)
        section "campus_preview keys and constraints"
        q "SELECT table_name, constraint_name, constraint_type FROM information_schema.table_constraints
           WHERE table_schema='campus_preview' ORDER BY table_name, constraint_type;"
        section "Enrolments (should still be 9 rows: the bad inserts were rejected)"
        q "SELECT COUNT(*) AS enrolments FROM campus_preview.enrolments;"
        recent_history 50 ;;
      4)
        section "Key server settings a DBA controls"
        q "SHOW VARIABLES WHERE variable_name IN ('port','bind_address','datadir','innodb_buffer_pool_size','log_error');"
        section "Server status"
        q "SHOW GLOBAL STATUS WHERE variable_name IN ('Uptime','Questions','Threads_connected');"
        section "Backup files you made"; list_files 'lab04*'
        recent_history 50 ;;
      5)
        answer_sheet_status 5
        section "Server facts (lecturer cross-checks Part B against these)"
        q "SELECT VERSION() AS version, @@port AS port, @@bind_address AS bind_address;"
        q "SELECT COUNT(*) AS preview_enrolments FROM campus_preview.enrolments;"
        recent_history 60 ;;
      6)
        section "Storage engines in use"
        q "SELECT table_schema, table_name, engine FROM information_schema.tables
           WHERE table_schema IN ('campus_preview','sheet_demo','sandbox') ORDER BY 1,2;"
        section "Buffer pool counters"
        q "SHOW GLOBAL STATUS WHERE variable_name IN ('Innodb_buffer_pool_read_requests','Innodb_buffer_pool_reads');"
        section "Does the sandbox database still exist? (lab ends with DROP DATABASE sandbox)"
        q "SELECT COUNT(*) AS sandbox_exists FROM information_schema.schemata WHERE schema_name='sandbox';"
        recent_history 60 ;;
      7)
        section "Tables in campusdb"
        q "SELECT table_name FROM information_schema.tables WHERE table_schema='campusdb' ORDER BY table_name;"
        section "Row counts"
        q "SELECT 'students' t, COUNT(*) n FROM campusdb.students UNION ALL
           SELECT 'courses', COUNT(*) FROM campusdb.courses UNION ALL
           SELECT 'enrolments', COUNT(*) FROM campusdb.enrolments UNION ALL
           SELECT 'fees', COUNT(*) FROM campusdb.fees;"
        section "Constraints"
        q "SELECT table_name, constraint_type, COUNT(*) AS how_many FROM information_schema.table_constraints
           WHERE table_schema='campusdb' GROUP BY table_name, constraint_type ORDER BY 1,2;"
        section "The status column added with ALTER TABLE"
        q "SELECT column_name, column_default FROM information_schema.columns
           WHERE table_schema='campusdb' AND table_name='students' AND column_name='status';"
        recent_history 80 ;;
      8)
        section "Wallets (the MoMo transaction table)"
        q "SELECT * FROM campusdb.wallets;"
        q "SELECT SUM(balance) AS total_money_in_system FROM campusdb.wallets;"
        section "Row counts after your DML work"
        q "SELECT 'students' t, COUNT(*) n FROM campusdb.students UNION ALL
           SELECT 'enrolments', COUNT(*) FROM campusdb.enrolments;"
        recent_history 80 ;;
      9)
        section "Backup files"; list_files '*.sql' '*.gz' '*.sha256'
        section "Checksum verification"
        ( cd "$WORK_DIR/backups" 2>/dev/null && sha256sum -c ./*.sha256 2>&1 ) || echo "(no checksum files in my-work/backups)"
        section "Binary logs (the server's change journal)"
        q "SHOW BINARY LOGS;"
        section "campusdb after your restore drill"
        q "SELECT COUNT(*) AS students FROM campusdb.students;"
        recent_history 60 ;;
      10)
        answer_sheet_status 10
        exam_w2_marks
        recent_history 80 ;;
    esac
  } > "$body"

  { cat "$body"; echo; echo "Integrity stamp: $(sha256sum "$body" | cut -c1-16)"; } > "$out"
  rm -f "$body"
  if [ "$lab" = "10" ]; then grep -E '^\s+\[(PASS|----)\]|Auto-marked' "$out"; fi
  ok "Evidence written to ${out#$REPO_DIR/}"
}

case "${1:-help}" in
  doctor)            cmd_doctor ;;
  hello)             cmd_hello "${2:-}" ;;
  start-lab)         cmd_start_lab "${2:-}" "${3:-}" ;;
  start-week)        cmd_start_week "${2:-}" ;;
  check)             cmd_check "${2:-}" ;;
  submit)            cmd_submit "${2:-}" ;;
  restart)           cmd_restart ;;
  snapshot)          cmd_snapshot ;;
  restore-snapshot)  cmd_restore_snapshot ;;
  update)            cmd_update ;;
  rootpw)            ensure_running; set_rootpw ;;
  help|-h|--help|*)  sed -n '2,20p' "$(readlink -f "$0")" | sed 's/^# \{0,1\}//' ;;
esac
