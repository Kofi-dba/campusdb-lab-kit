# Lab 4 — A day in the life of a DBA

**Week 1 · Syllabus: Theory 5 (The DBA role) · Time: about 2 hours**

> **Goal:** perform one small, real task for each of the **six duties of a Database
> Administrator**, on your own server. By the end you'll know *what* each duty is,
> *when* a DBA does it, and *which command* they reach for.

A **DBA** keeps the database **available, correct, fast and safe**. In the library,
the DBA is the **head librarian**.

---

## Before you start

```bash
labctl hello 4
labctl start-lab 4      # type YES
```

You'll switch between the `$` prompt and `mysql>` today. Each step says which one.

---

## Duty 1 — Installation and configuration

### 📇 Know-how card

| | |
|---|---|
| **What it is** | Installing the DBMS and choosing its settings: which port, where the data lives, how much memory it uses. |
| **When** | When a server is built, and whenever it needs tuning (more users, more data, new security rules). |
| **How** | Settings live in a config file (`my.cnf`, or `mysqld.cnf` on Ubuntu). You read the live values with `SHOW VARIABLES`. |
| **Analogy** | Building the library and fitting the shelves. |

### Step 1 — Read the five settings every DBA knows (`mysql>`)

```bash
mysql -u root -p
```

```sql
SHOW VARIABLES WHERE variable_name IN
  ('port', 'bind_address', 'datadir', 'innodb_buffer_pool_size', 'log_error');

-- The buffer pool is shown in bytes; convert it to megabytes
SELECT @@innodb_buffer_pool_size / 1024 / 1024 AS buffer_pool_mb;
```

| Setting | What it controls | Why a DBA cares | Your value |
|---|---|---|---|
| `port` | Which network "door number" the server listens on (default 3306) | Firewalls and attack surface | |
| `bind_address` | Which network addresses may connect | `127.0.0.1` = local only, safer | |
| `datadir` | Where the data files live | Disk space, backups | |
| `innodb_buffer_pool_size` | Memory used to cache data | The main performance lever | |
| `log_error` | Where errors are written | First place to look when things break | |

Copy the table into `my-work/lab04-notes.md` and fill the last column.

---

## Duty 2 — Security and access control

### 📇 Know-how card

| | |
|---|---|
| **What it is** | Creating accounts and giving each one the **least** access its job needs. |
| **When** | When staff join, change jobs or leave; and in regular access reviews. |
| **How** | Check who has accounts in `mysql.user`; create and grant in week 3. |
| **Analogy** | Issuing library cards and deciding which rooms each card opens. |

### Step 2 — Audit the accounts (`mysql>`)

```sql
SELECT user, host, account_locked, password_last_changed
FROM mysql.user
ORDER BY user;
```

**Ask yourself as the DBA:** which accounts are for people, and which are for MySQL
itself? The `mysql.*` accounts are internal and **locked** (`account_locked = Y`):
nobody can log in with them. Is there any account with `host = '%'` (any machine)?
There shouldn't be.

---

## Duty 3 — Backup and recovery

### 📇 Know-how card

| | |
|---|---|
| **What it is** | Taking regular copies of the data and **proving** you can restore them. |
| **When** | On a schedule (e.g. every night), before any risky change, and restore-tested regularly. |
| **How** | `mysqldump` makes a *logical* backup: a file of SQL that rebuilds everything. Full lab in week 2 (lab 9). |
| **Analogy** | Photocopies of the catalogue kept in a fireproof safe off-site. |

### Step 3 — Take your first backup (`$`)

Type `exit` to leave MySQL, then:

```bash
mysqldump -u root -p campus_preview > my-work/lab04_preview_backup.sql
ls -lh my-work/lab04_preview_backup.sql      # how big is it?
head -40 my-work/lab04_preview_backup.sql    # look inside: it's readable SQL
```

```text
mysqldump          the backup tool (it ships with MySQL)
campus_preview     which database to copy
>                  "send the output into this file instead of the screen"
```

Find the `CREATE TABLE` and `INSERT INTO` lines. A logical backup is **instructions
to rebuild** the shelves and re-file every card.

---

## Duty 4 — Performance tuning

### 📇 Know-how card

| | |
|---|---|
| **What it is** | Keeping queries fast: indexes, good queries, enough memory. |
| **When** | When users complain, when results-release day is coming, when data grows. |
| **How** | `EXPLAIN` shows **how** MySQL plans to find your data before it runs the query. |
| **Analogy** | Rearranging shelves so popular books are near the desk. An **index** is the catalogue: it tells the librarian exactly where a book is instead of walking every shelf. |

### Step 4 — Compare a fast and a slow search (`mysql>`)

```bash
mysql -u root -p
```

```sql
USE campus_preview;

-- Search by the primary key (it has an index)
EXPLAIN SELECT * FROM students WHERE student_id = 10452;

-- Search by last name (no index)
EXPLAIN SELECT * FROM students WHERE last_name = 'Mensah';
```

Look at the `type` and `key` columns:

| Query | `type` | `key` | Meaning |
|---|---|---|---|
| By `student_id` | `const` | `PRIMARY` | Went straight to one row using the index |
| By `last_name` | `ALL` | `NULL` | **Full table scan**: read every row to find Mensah |

With 4 students, both are instant. With 4 million, the full scan is the slow
results portal on release day. The fix (creating an index) comes later in the course.

```sql
-- Three numbers a DBA glances at every day
SHOW GLOBAL STATUS WHERE variable_name IN ('Uptime', 'Questions', 'Threads_connected');
```

| Counter | Meaning |
|---|---|
| `Uptime` | Seconds since the server started |
| `Questions` | Statements received since then |
| `Threads_connected` | How many sessions are connected right now |

---

## Duty 5 — Monitoring and auditing

### 📇 Know-how card

| | |
|---|---|
| **What it is** | Watching who is connected, what they're doing, and what went wrong. |
| **When** | Constantly (with alerts), and immediately when something breaks. |
| **How** | `SHOW PROCESSLIST` for live sessions; the **error log** for problems; audit logs for "who changed what" (week 4). |
| **Analogy** | Reading the visitors' sign-in book and watching the CCTV. |

### Step 5 — See who's in the library right now

Open a **second terminal** (the **+** at the top right of the terminal panel) and
log in there too: `mysql -u root -p`. Then, in the **first** terminal:

```sql
SHOW PROCESSLIST;
```

**What you should see:** a row for each connection, including your second terminal
(`Command = Sleep`, waiting for you) and your own `SHOW PROCESSLIST` query
(`Command = Query`). You may also see `event_scheduler`, a built-in MySQL helper.
Type `exit` in the second terminal.

### Step 6 — Read the error log (`$`)

Type `exit`, then:

```bash
sudo tail -n 20 /var/log/mysql/error.log
```

Find the line saying the server is `ready for connections`, and its version. When
MySQL won't start, this file tells you why. **It's the first place a DBA looks.**

---

## Duty 6 — Upgrades and patching

### 📇 Know-how card

| | |
|---|---|
| **What it is** | Applying the vendor's fixes, especially **security** fixes. |
| **When** | On a regular schedule, and urgently when a critical vulnerability is announced. Test on a copy first. |
| **How** | Know your exact version, read the vendor's release notes, update through the system's package manager. |
| **Analogy** | Replacing broken locks when a flaw is found. |

### Step 7 — Know exactly what you're running (`$`)

```bash
mysql -u root -p -e "SELECT VERSION();"
apt list --installed 2>/dev/null | grep mysql-server
```

```text
-e "..."   run one SQL statement and come straight back to the $ prompt
```

Write down the full version (e.g. `8.0.46-0ubuntu0.24.04.4`). A DBA compares this with
the vendor's latest release notes to decide whether an update is needed.

---

## Part 2 — Scenario cards: which duty?

For each situation, write which DBA duty handles it, and **the command you met today**
that you'd reach for first:

1. The results portal is very slow on the day results are released.
2. A lecturer can see the fees table.
3. The server's disk failed overnight.
4. MySQL announced a critical vulnerability.
5. Someone deleted 300 records and nobody knows who.
6. *(Your own)* Write one scenario for a classmate.

---

## ✅ Check your understanding

In `my-work/lab04-notes.md`:

1. Your filled-in settings table from Duty 1.
2. The six DBA duties, each with **one command** from today.
3. What does `type: ALL` mean in `EXPLAIN`, and why does it matter on a big table?
4. Your answers to the scenario cards.

---

## 📤 Submit

```bash
labctl submit 4
```

## 🧠 Key terms from today

| Duty | What it means in practice | Command you used | Library analogy |
|---|---|---|---|
| Installation and configuration | Install, tune memory, set ports | `SHOW VARIABLES` | Building the library, fitting shelves |
| Security and access control | Accounts, least privilege | `SELECT … FROM mysql.user` | Issuing library cards |
| Backup and recovery | Scheduled backups, tested restores | `mysqldump` | Catalogue copies in an off-site safe |
| Performance tuning | Indexes, good queries, memory | `EXPLAIN`, `SHOW GLOBAL STATUS` | Popular books near the desk |
| Monitoring and auditing | Who's connected, what failed | `SHOW PROCESSLIST`, error log | Sign-in book and CCTV |
| Upgrades and patching | Apply vendor fixes | `SELECT VERSION()` | Replacing broken locks |
