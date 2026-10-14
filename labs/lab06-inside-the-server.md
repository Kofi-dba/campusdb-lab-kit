# Lab 6 — Inside the server, and the three families of SQL

**Week 2 · Syllabus: Theory 1 (How a DBMS server is organised) and Theory 2 (The three families of SQL) · Time: about 2 hours**

> **Goal:** follow a query from your keyboard to the disk and back, see the storage
> engine and its memory cache at work, change a server setting, and practise the
> three families of SQL (DDL, DML, DCL) in a throw-away `sandbox` database,
> including the most dangerous line in SQL.

---

## Before you start

```bash
labctl hello 6
labctl start-lab 6      # type YES
```

---

## Part 1 — The journey of a query

### 📇 Know-how card: client–server

| | |
|---|---|
| **What it is** | A DBMS is a **client–server** system. The client (`mysql`, Workbench, a web app) sends SQL; the server (`mysqld`) checks it, plans it, and fetches the data through a **storage engine**. |
| **When it matters** | Always: every app, report and admin task follows this path. It's why a DBA can protect the data in **one** place. |
| **Analogy** | A restaurant. The **customer** (client) orders from the **waiter** (server process). The waiter checks the order is allowed ("sorry, the bar is closed to under-18s"), the **chef** (optimiser) decides how to cook it fastest, and the **kitchen store** (storage engine) fetches ingredients from the **fridge** (disk). Popular ingredients already sit on the **counter** (buffer pool / memory cache). |

```text
 Client (you)      MySQL server                     InnoDB engine        Disk files
     │  SELECT ...  │                                    │                    │
     │─────────────►│ 1. check login and privileges      │                    │
     │              │ 2. parse and optimise the query    │                    │
     │              │ 3. fetch rows ────────────────────►│ read pages ───────►│
     │              │                                    │ (or use the memory │
     │              │◄──────────────────────── rows ─────│  cache if there)   │
     │◄─ result set │                                    │                    │
```

> Step 1 happens on **every single query**, not just at login. That's where week 3 lives.

### Step 1 — Two roads to the server: socket and network

```bash
mysql -u root -p
```

```sql
\s
```

(`\s` = **status**: shows facts about your current connection.)

Find the `Connection:` line. It says **`Localhost via UNIX socket`**: a private pipe
inside the machine. Type `exit`, then connect over the **network** (TCP/IP) instead:

```bash
mysql -u root -p -h 127.0.0.1
```

```sql
\s
```

Now it says **`127.0.0.1 via TCP/IP`**, the same road a web app on another server
would use, just looping back to this machine. Note the `TCP port: 3306`.

| Road | When it's used | Analogy |
|---|---|---|
| UNIX socket | Client and server on the **same** machine | A staff-only internal corridor |
| TCP/IP (`-h host`) | Client on **another** machine, or `-h 127.0.0.1` | The public street to the front door (port 3306 = door number) |

---

## Part 2 — The storage engine and its memory cache

### 📇 Know-how card: storage engine (InnoDB)

| | |
|---|---|
| **What it is** | The part of MySQL that actually stores and retrieves rows on disk. **InnoDB** is the default: it supports transactions, foreign keys and crash recovery. |
| **When you choose it** | Practically always in MySQL 8. Older engines (MyISAM) lack transactions and foreign keys. |
| **How you see it** | `SHOW ENGINES;` and the `engine` column in `information_schema.tables`. |

### Step 2 — Which engine are your tables using?

```sql
SHOW ENGINES;     -- look for InnoDB with Support = DEFAULT

SELECT table_schema, table_name, engine
FROM information_schema.tables
WHERE table_schema IN ('campus_preview', 'sheet_demo');
```

### Step 3 — Where are the files? (`$`)

```bash
exit
sudo ls -lh /var/lib/mysql/campus_preview/
```

**What you should see:** one `.ibd` file per table (`students.ibd`, `enrolments.ibd`…).
That's the fridge. You may look with `sudo`, but **you never edit these files by hand**:
only the server touches them.

### 📇 Know-how card: buffer pool (memory cache)

| | |
|---|---|
| **What it is** | Memory where InnoDB keeps recently used data pages, so it doesn't go to disk every time. |
| **When it matters** | Performance. Reading from memory is thousands of times faster than from disk. Sizing it (`innodb_buffer_pool_size`) is a DBA's main performance lever. |
| **Analogy** | The ingredients already on the counter, so the chef doesn't walk to the fridge for every dish. |

### Step 4 — Watch the cache work (`mysql>`)

```bash
mysql -u root -p
```

```sql
-- read_requests = asked for a page;  reads = had to go to DISK for it
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read%s';

SELECT COUNT(*) FROM campus_preview.enrolments;   -- do some work
SELECT COUNT(*) FROM campus_preview.enrolments;   -- same work again

SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read%s';
```

Compare the two counters before and after. `Innodb_buffer_pool_read_requests` goes up;
`Innodb_buffer_pool_reads` (disk trips) barely moves, because the pages were already
on the counter.

```sql
-- The cache hit ratio: how often the answer was already in memory (aim for 99%+)
SELECT ROUND(100 * (1 - r.v / q.v), 2) AS hit_ratio_percent
FROM (SELECT variable_value AS v FROM performance_schema.global_status
      WHERE variable_name = 'Innodb_buffer_pool_reads') r,
     (SELECT variable_value AS v FROM performance_schema.global_status
      WHERE variable_name = 'Innodb_buffer_pool_read_requests') q;
```

---

## Part 3 — Configuration: changing a setting

### 📇 Know-how card: runtime vs permanent settings

| | |
|---|---|
| **What it is** | `SET GLOBAL` changes a setting **now**, until the next restart. The config file (`/etc/mysql/mysql.conf.d/mysqld.cnf`) holds settings that survive restarts. |
| **When** | Use `SET GLOBAL` to test or fix something immediately; put it in the config file once you're sure. |
| **Analogy** | Moving a shelf for today's event vs changing the library's floor plan. |

### Step 5 — Change, check, restart, check again

```sql
SELECT @@max_connections;            -- how many people may be connected at once (default 151)
SET GLOBAL max_connections = 200;    -- change it now
SELECT @@max_connections;            -- 200
exit
```

```bash
labctl restart                       # switch the server off and on again
mysql -u root -p -e "SELECT @@max_connections;"
```

**What you should see:** back to **151**. `SET GLOBAL` didn't survive the restart,
because it never reached the config file. Write in your notes why a DBA must know this.

---

## Part 4 — The three families of SQL

### 📇 Know-how card: DDL, DML, DCL

| Family | Stands for | Commands | Who uses it most | Library analogy |
|---|---|---|---|---|
| **DDL** | Data **Definition** Language | `CREATE`, `ALTER`, `DROP` | DBA, developers | Building or removing shelves |
| **DML** | Data **Manipulation** Language | `SELECT`, `INSERT`, `UPDATE`, `DELETE` | Applications, users | Adding, reading, editing, removing cards |
| **DCL** | Data **Control** Language | `GRANT`, `REVOKE` | DBA | Issuing or cancelling library-card access |

**When you use each:** DDL when the *shape* of the data changes (new table, new
column). DML every day, for the data itself. DCL when *people* change (new staff,
someone leaves).

### Step 6 — Practise each family in a sandbox (`mysql>`)

```bash
mysql -u root -p
```

```sql
-- ===== DDL: build the shelf =====
CREATE DATABASE sandbox;                            -- a new wing
USE sandbox;
CREATE TABLE notes (                                -- a new shelf
  note_id INT PRIMARY KEY,
  body    VARCHAR(100)
);
ALTER TABLE notes ADD COLUMN author VARCHAR(50);    -- change the shelf: add a column
DESCRIBE notes;

-- ===== DML: work with the cards =====
INSERT INTO notes VALUES (1, 'First note', 'Ama'), (2, 'Second note', 'Kwame');
SELECT * FROM notes;
UPDATE notes SET body = 'Edited note' WHERE note_id = 1;   -- WHERE = only this row
DELETE FROM notes WHERE note_id = 2;                       -- WHERE = only this row
SELECT * FROM notes;

-- ===== DCL: who may do what =====
SHOW GRANTS FOR CURRENT_USER();      -- root's privileges (GRANT/REVOKE in week 3)
```

### Step 7 — The most dangerous line in SQL

```sql
-- Make a copy of the students table to experiment on (never practise on real data!)
CREATE TABLE students_copy AS SELECT * FROM campus_preview.students;
SELECT COUNT(*) FROM students_copy;    -- 4

DELETE FROM students_copy;             -- no WHERE!
SELECT COUNT(*) FROM students_copy;    -- 0: every student is gone
```

No warning, no "are you sure?". Without a `WHERE`, `DELETE` and `UPDATE` hit
**every row**. This is why backups and least privilege exist.

### 📇 Know-how card: safe-updates mode

| | |
|---|---|
| **What it is** | A client option that **refuses** `UPDATE` and `DELETE` statements without a `WHERE` on a key column. |
| **When** | Whenever you connect to a **real** (production) database by hand. Many DBAs make it their default. |
| **How** | `mysql -u root -p --safe-updates` |

```sql
exit
```

```bash
mysql -u root -p --safe-updates
```

```sql
INSERT INTO sandbox.students_copy SELECT * FROM campus_preview.students;
DELETE FROM sandbox.students_copy;     -- refused!
```

**What you should see:** `ERROR 1175 (HY000): You are using safe update mode and you
tried to update a table without a WHERE that uses a KEY column.`

### Step 8 — Remove the whole wing

```sql
DROP DATABASE sandbox;    -- DDL: removes the database and EVERYTHING in it, instantly
SHOW DATABASES;           -- sandbox is gone
exit
```

> `DROP DATABASE campusdb;` would do the same to a whole university's records.
> Only a backup brings it back (lab 9).

---

## ✅ Check your understanding

In `my-work/lab06-notes.md`:

1. Put these in order and say who does each (client, server, engine, disk): *fetch rows*, *check privileges*, *send SQL*, *parse and optimise*, *read pages*.
2. What is the difference between the UNIX socket and TCP/IP? When is each used?
3. What is the buffer pool, and what was your hit ratio?
4. Why did `max_connections` go back to 151 after the restart?
5. Classify: `CREATE TABLE`, `UPDATE`, `GRANT`, `DROP`, `SELECT`, `ALTER`, `REVOKE`, `INSERT`.
6. What does `DELETE FROM students;` do? Give two protections against it.

---

## 📤 Submit

```bash
labctl submit 6
```

## 🧠 Key terms from today

| Term | What it is | Analogy |
|---|---|---|
| Client–server | Client sends SQL; server checks, plans and runs it | Customer, waiter, kitchen |
| Optimiser | Decides the fastest way to answer a query | The chef |
| Storage engine (InnoDB) | Stores and fetches rows on disk | The kitchen store |
| Buffer pool | Memory cache of data pages | Ingredients on the counter |
| UNIX socket / TCP/IP | Local pipe / network road to the server | Staff corridor / public street |
| `SET GLOBAL` | Change a setting until restart | Today's shelf arrangement |
| DDL / DML / DCL | Define structure / handle data / control access | Shelves / cards / library cards |
| `--safe-updates` | Refuses UPDATE/DELETE without a key in WHERE | A "are you sure?" lock on the shredder |
