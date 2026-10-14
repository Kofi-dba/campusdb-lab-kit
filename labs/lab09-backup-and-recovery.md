# Lab 9 — Backup and recovery

**Week 2 · Syllabus: Theory 5 (Backup and recovery fundamentals) and Lab 2 step 5 · Time: about 2 hours**

> **Goal:** take a proper backup, prove it isn't corrupted, compress it, store copies
> by the 3-2-1 rule, then survive a disaster: drop the database, restore it, and
> **measure** your RTO and RPO. Finally, peek at the binary log, the journal that
> makes "incremental" backups and point-in-time recovery possible.

> **A backup you have never restored is a hope, not a backup.**

---

## Before you start

```bash
labctl hello 9
labctl start-lab 9      # type YES: a complete campusdb with 6 students
```

---

## Part 1 — The ideas (read before typing)

### 📇 Know-how card: logical vs physical backups

| | Logical backup | Physical backup |
|---|---|---|
| **What it copies** | SQL statements that **rebuild** the data (`CREATE TABLE…`, `INSERT…`) | The raw data **files** from disk |
| **Tool** | `mysqldump` (today) | MySQL Enterprise Backup, Percona XtraBackup, disk snapshots |
| **Speed** | Slow for big databases | Fast |
| **Portable?** | Yes: readable, works on another version or machine | Tied to the same version and platform |
| **When** | Small/medium databases, moving data, keeping a readable copy | Large databases where restore speed matters |
| **Analogy** | Written instructions to rebuild the shelves and re-file every card | A photocopy of every shelf exactly as it stands |

### 📇 Know-how card: full, incremental, differential

| Type | What it copies | Speed to take | To restore you need |
|---|---|---|---|
| **Full** | Everything | Slowest | Just this backup |
| **Incremental** | Changes since the last backup **of any type** | Fastest | Last full **+ every** incremental since |
| **Differential** | Changes since the last **full** | Medium | Last full **+ the latest** differential |

Example week: full on Sunday. On Thursday, *incremental* needs Sun + Mon + Tue + Wed;
*differential* needs Sun + Wed only.

### 📇 Know-how card: the 3-2-1 rule

| | |
|---|---|
| **What it is** | **3** copies of the data, on **2** different types of storage, with **1** off-site (or in another cloud region). |
| **Why** | One fire, one ransomware attack, or one failed disk must never take every copy. |
| **Analogy** | Your WASSCE certificate: the original (copy 1), a photocopy at home in a different folder (copy 2, different medium), and a scan in your email (copy 3, off-site). A fire at home doesn't erase your qualification. |

### 📇 Know-how card: RPO and RTO

| | |
|---|---|
| **RPO** (Recovery Point Objective) | How much **data** you can afford to lose. "At most 1 hour" means backups at least hourly. |
| **RTO** (Recovery Time Objective) | How long you can afford to be **down**. "Back online within 4 hours." |
| **When** | A DBA agrees both numbers with management **before** disaster, then designs backups to meet them. |

---

## Part 2 — Store the password safely first

Today you'll run many backup and restore commands. Typing the root password each
time is slow, and putting it **inside** a command or script is dangerous (anyone
reading the script or the command history sees it).

### 📇 Know-how card: login paths (`mysql_config_editor`)

| | |
|---|---|
| **What it is** | A MySQL tool that stores login details in an obscured file (`~/.mylogin.cnf`) that only you can read. |
| **When** | For backup scripts and repeated admin work. Never write passwords in scripts. |
| **How** | Save once with `mysql_config_editor set`; then use `--login-path=name` (always as the **first** option). |

```bash
mysql_config_editor set --login-path=lab --user=root --password
# Enter: ChangeMe!2026

mysql --login-path=lab -e "SELECT CURRENT_USER();"   # logged in, no password typed
```

> Real servers go further and use a dedicated **backup account** with only the
> privileges a backup needs (week 3), never root.

---

## Part 3 — Take, check and compress a full backup

### Step 1 — Full logical backup

```bash
mkdir -p my-work/backups

mysqldump --login-path=lab --single-transaction --routines --triggers campusdb \
  > my-work/backups/campusdb_full.sql
```

```text
--single-transaction   take a consistent snapshot WITHOUT locking users out
                       (InnoDB only: everyone keeps working during the backup)
--routines --triggers  include stored code too, not just tables
>                      write into this file
\                      the command continues on the next line
```

Write down the **time** you took the backup: it matters in Part 5.

```bash
date
ls -lh my-work/backups/
grep 'CREATE TABLE' my-work/backups/campusdb_full.sql        # the 4 shelves
grep -c 'INSERT INTO' my-work/backups/campusdb_full.sql      # how many INSERT lines
```

### Step 2 — Prove the file isn't corrupted: a checksum

### 📇 Know-how card: checksum (SHA-256)

| | |
|---|---|
| **What it is** | A fingerprint of a file. Change one byte and the fingerprint changes completely. |
| **When** | After every backup, and again before restoring: it proves the copy you restore is exactly the copy you took. |

```bash
cd my-work/backups
sha256sum campusdb_full.sql > campusdb_full.sha256     # save the fingerprint
cat campusdb_full.sha256
sha256sum -c campusdb_full.sha256                      # verify: should say OK
cd -
```

### Step 3 — Compress it

```bash
gzip -k my-work/backups/campusdb_full.sql     # -k = keep the original too
ls -lh my-work/backups/                       # compare the sizes
```

Text backups compress very well, often to a fraction of the size. Smaller backups
are faster to copy off-site.

---

## Part 4 — Apply the 3-2-1 rule

| Copy | Where it is in this lab | Where it would be in a real organisation |
|---|---|---|
| 1 | The live `campusdb` database | The production server |
| 2 | `my-work/backups/` on this machine | A **different type** of storage: a backup server, NAS, tape |
| 3 | **Off-site:** your GitHub repository (after `labctl submit 9`) | Another building, or a cloud bucket in another region |

> Honest note: copies 1 and 2 are on the same disk here, so this lab only *models*
> the "2 media" part. In your homework plan, say what you'd use instead.

---

## Part 5 — The disaster drill: measure RPO and RTO

### Step 4 — Business continues after the backup

```bash
mysql --login-path=lab campusdb -e "
  INSERT INTO students (student_id, first_name, last_name, email, programme)
  VALUES (10458, 'Abena', 'Ofori', 'abena.o@campus.edu.gh', 'BSc IT');
  SELECT student_id, first_name FROM students;"
```

Abena registered **after** your backup. Note her.

### Step 5 — Disaster

```bash
mysql --login-path=lab -e "DROP DATABASE campusdb;"
mysql --login-path=lab -e "SHOW DATABASES;"            # campusdb is gone
```

### Step 6 — Restore, with a stopwatch

```bash
(cd my-work/backups && sha256sum -c campusdb_full.sha256)       # 1. verify the copy: OK?

time ( mysql --login-path=lab -e "CREATE DATABASE campusdb;" && \
       mysql --login-path=lab campusdb < my-work/backups/campusdb_full.sql )   # 2. restore
```

`time` prints how long the restore took (`real`). That's your **measured RTO** for
this database: the time from "start restoring" to "back online".

> 💡 You could restore from the compressed copy just as well:
> `gunzip -c my-work/backups/campusdb_full.sql.gz | mysql --login-path=lab campusdb`

### Step 7 — What did we lose?

```bash
mysql --login-path=lab campusdb -e "SELECT COUNT(*) AS students FROM students;"
mysql --login-path=lab campusdb -e "SELECT * FROM students WHERE student_id = 10458;"
```

**What you should see:** 6 students, and **no Abena**. She registered after the
backup, so the backup never had her. The gap between your backup time and the
disaster is your **actual RPO**. If backups ran every night, you could lose up to a
whole day of registrations.

---

## Part 6 — The binary log: where "incremental" comes from

### 📇 Know-how card: binary log (binlog)

| | |
|---|---|
| **What it is** | A journal where MySQL records **every change** (INSERT, UPDATE, DELETE, DDL) as it happens. |
| **When it's used** | Incremental backups (save the journal files since the last full backup), **point-in-time recovery** (restore the full backup, then replay the journal up to one second before the disaster), and replication. |
| **Analogy** | The library's loans ledger: even if the catalogue burns, you can rebuild every change since last Sunday's photocopy by reading the ledger. |

### Step 8 — Find Abena in the journal

```bash
mysql --login-path=lab -e "SHOW VARIABLES LIKE 'log_bin'; SHOW BINARY LOGS;"
```

`log_bin` should be `ON`, with files called `binlog.000001`, `binlog.000002`…
Now read them, decoded into readable form. (`sudo sh -c '…'` runs the whole command as
the administrator, because only MySQL's own account may open its data folder.)

```bash
sudo sh -c 'mysqlbinlog --base64-output=DECODE-ROWS -v /var/lib/mysql/binlog.[0-9]*' \
  | grep -B3 -A8 "10458"
```

**What you should see:** lines like `### INSERT INTO `campusdb`.`students``
`### SET  @1=10458  @2='Abena' …`. Abena's registration **was** recorded, even though
your backup missed her. With point-in-time recovery, a DBA could replay this entry
after the restore and lose **nothing**: RPO close to zero. (Replaying is beyond
today's lab; knowing it's possible is the point.)

---

## Part 7 — Physical size, for comparison

```bash
sudo du -sh /var/lib/mysql                       # the whole data directory
du -sh my-work/backups/campusdb_full.sql.gz      # your compressed logical backup
```

A physical backup would copy that whole data directory, which is why it's fast to
restore but big and tied to this exact MySQL version.

---

## ✅ Check your understanding

In `my-work/lab09-notes.md`:

1. Logical vs physical: which did you do today, and when would you choose the other?
2. It's Thursday. Sunday was a full backup. Which backups do you need with an **incremental** scheme? With a **differential** one?
3. Your measured RTO from Step 6, and what your RPO was in Step 7 (in minutes).
4. Why did the restore not bring Abena back? What would?
5. Why use `--login-path` instead of writing the password in a backup script?

### Homework (from the syllabus)

Write a one-page backup plan for CampusDB in `my-work/backup-plan.md`: backup type,
frequency, where the 3 copies are stored (with real storage types), RPO and RTO, and
who tests a restore, and how often.

---

## 📤 Submit

```bash
labctl submit 9
```

This also uploads `my-work/backups/` to GitHub: that's your **off-site copy** (copy 3).

## 🧠 Key terms from today

| Term | What it is | When you use it |
|---|---|---|
| `mysqldump` | Logical backup tool | Small/medium databases, portable copies |
| `--single-transaction` | Consistent backup without locking users out | Every InnoDB backup |
| Full / incremental / differential | Everything / since last any / since last full | Designing a backup schedule |
| Checksum (`sha256sum`) | A file's fingerprint | After backing up and before restoring |
| 3-2-1 rule | 3 copies, 2 media, 1 off-site | Deciding where backups live |
| RPO / RTO | Acceptable data loss / acceptable downtime | Agreed with management before disaster |
| Binary log | Journal of every change | Incremental backups, point-in-time recovery |
| `--login-path` | Stored, obscured credentials | Scripts and repeated admin work |
