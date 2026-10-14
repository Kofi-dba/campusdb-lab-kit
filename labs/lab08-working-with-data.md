# Lab 8 — Working with data (DML) and transactions (ACID)

**Week 2 · Syllabus: Theory 2 (DML) and Theory 4 (Transactions and ACID) · Time: about 2 hours**

> **Goal:** become fluent in the four everyday statements (`SELECT`, `INSERT`,
> `UPDATE`, `DELETE`) with safe habits, then prove each letter of **ACID** with a
> Mobile Money transfer, including what happens when something goes wrong halfway.

---

## Before you start

```bash
labctl hello 8
labctl start-lab 8      # type YES: gives you a complete campusdb with 6 students
mysql -u root -p
```

```sql
USE campusdb;
```

> Your lab 7 database is replaced by a standard one, so everyone starts from the same
> data. (Your lab 7 script is still safe in `my-work/`.)

---

## Part 1 — SELECT: asking questions

### 📇 Know-how card: SELECT

| | |
|---|---|
| **What it is** | Reads data. It never changes anything, so it's always safe to run. |
| **When** | Every report, every screen of an app, and **before every UPDATE or DELETE** (to see what you're about to change). |
| **Shape** | `SELECT columns FROM table WHERE condition ORDER BY column LIMIT n;` |
| **Analogy** | A request slip: "please show me these cards". |

```sql
SELECT * FROM students;                                   -- every column, every row
SELECT first_name, last_name FROM students;               -- only some columns
SELECT * FROM students WHERE programme = 'BSc IT';        -- only some rows
SELECT * FROM students WHERE last_name LIKE 'A%';         -- last name starts with A
SELECT * FROM enrolments WHERE score BETWEEN 60 AND 75;   -- a range
SELECT * FROM enrolments ORDER BY score DESC LIMIT 3;     -- top 3 scores
```

### Summaries: COUNT, SUM, AVG, MIN, MAX and GROUP BY

```sql
SELECT COUNT(*) AS students FROM students;                 -- how many rows
SELECT AVG(score) AS average, MAX(score) AS best FROM enrolments;
SELECT SUM(amount_ghs) AS total_fees FROM fees;

-- One result PER course: GROUP BY makes one pile per course, then summarises each pile
SELECT course_code, COUNT(*) AS students, ROUND(AVG(score), 1) AS average
FROM enrolments
GROUP BY course_code;
```

### Combining tables: JOIN and LEFT JOIN

| Join | Returns | When to use it |
|---|---|---|
| `JOIN` (inner) | Only rows that match in **both** tables | "Students **with** their scores" |
| `LEFT JOIN` | **Every** row from the left table, matched or not | "**All** students, and their fees **if any**" (finds who hasn't paid) |

```sql
-- Students with their course scores
SELECT s.first_name, s.last_name, e.course_code, e.score
FROM students s
JOIN enrolments e ON s.student_id = e.student_id;

-- Who has paid NO fees at all?
SELECT s.student_id, s.first_name, s.last_name
FROM students s
LEFT JOIN fees f ON f.student_id = s.student_id
WHERE f.payment_id IS NULL;          -- no matching payment row
```

---

## Part 2 — INSERT, UPDATE, DELETE with safe habits

### 📇 Know-how card: INSERT

| | |
|---|---|
| **What it is** | Adds new rows. |
| **When** | New student registers, new payment, new enrolment. |
| **Safe habit** | Always **name the columns**: `INSERT INTO t (a, b) VALUES (…)`. If the table changes later, your statement still puts values in the right places. |

```sql
INSERT INTO students (student_id, first_name, last_name, email, programme)
VALUES (10458, 'Abena', 'Ofori', 'abena.o@campus.edu.gh', 'BSc IT');

INSERT INTO enrolments (student_id, course_code, score) VALUES (10458, 'DBA401', NULL);
INSERT INTO fees (student_id, amount_ghs, paid_on) VALUES (10458, 4500.00, CURDATE());
-- CURDATE() = today's date
```

### 📇 Know-how card: UPDATE

| | |
|---|---|
| **What it is** | Changes values in existing rows. |
| **When** | A score is marked, a phone number changes, a mistake is corrected. |
| **Safe habit** | **SELECT first, with the same WHERE.** Check exactly which rows will change, *then* turn the SELECT into an UPDATE. |

```sql
-- 1. Look first: which row is Abena's DBA401 enrolment?
SELECT * FROM enrolments WHERE student_id = 10458 AND course_code = 'DBA401';

-- 2. Same WHERE, now change it
UPDATE enrolments SET score = 74 WHERE student_id = 10458 AND course_code = 'DBA401';

-- 3. Check MySQL's reply: "Rows matched: 1  Changed: 1". 1 is what you expected.
SELECT * FROM enrolments WHERE student_id = 10458;
```

### 📇 Know-how card: DELETE

| | |
|---|---|
| **What it is** | Removes rows. |
| **When** | Rarely: a duplicate entered by mistake, a cancelled enrolment. Many systems never delete; they mark rows inactive instead. |
| **Safe habit** | SELECT first. Never run `DELETE` without `WHERE` (remember lab 6). |

```sql
SELECT * FROM enrolments WHERE student_id = 10458;       -- look first
DELETE FROM enrolments WHERE student_id = 10458;         -- Abena drops the course

DELETE FROM students WHERE student_id = 10458;           -- try to remove Abena
```

**What you should see:** the second `DELETE` fails with `ERROR 1451`: her fee
payment still points at her. The foreign key protects the financial record.

---

## Part 3 — Transactions and ACID

### 📇 Know-how card: transaction

| | |
|---|---|
| **What it is** | A group of changes that **succeed or fail together**. |
| **When** | Whenever one real-world action needs several changes: a MoMo transfer (debit + credit), a course registration (enrolment + fee invoice), a stock sale (sale + stock count). |
| **How** | `START TRANSACTION;` … your changes … then `COMMIT;` (make permanent) or `ROLLBACK;` (undo everything since START). |
| **Analogy** | A MoMo transfer of GHS 200 from Ama to Kwame is two steps: subtract from Ama, add to Kwame. If the system crashes between the steps, money vanishes. A transaction is the sealed envelope holding both steps: delivered whole, or not at all. |

### 📇 Know-how card: autocommit

| | |
|---|---|
| **What it is** | By default MySQL **commits every statement on its own**, immediately. |
| **When it matters** | Outside `START TRANSACTION`, there's no undo: each `UPDATE` is final the moment you press Enter. |

```sql
SELECT @@autocommit;     -- 1 = ON
```

### Step 1 — Create the wallets

```sql
CREATE TABLE wallets (
  owner   VARCHAR(30) PRIMARY KEY,
  balance DECIMAL(10,2) NOT NULL CHECK (balance >= 0)   -- nobody may go below zero
);
INSERT INTO wallets VALUES ('Ama', 500.00), ('Kwame', 100.00);
SELECT * FROM wallets;    -- total money in the system: 600
```

### A — Atomicity: all steps or none

```sql
START TRANSACTION;
UPDATE wallets SET balance = balance - 200 WHERE owner = 'Ama';
UPDATE wallets SET balance = balance + 200 WHERE owner = 'Kwame';
SELECT * FROM wallets;    -- Ama 300, Kwame 300 (only YOU can see this so far)
ROLLBACK;                 -- the "power cut": undo both steps
SELECT * FROM wallets;    -- back to Ama 500, Kwame 100
```

Now do it for real:

```sql
START TRANSACTION;
UPDATE wallets SET balance = balance - 200 WHERE owner = 'Ama';
UPDATE wallets SET balance = balance + 200 WHERE owner = 'Kwame';
COMMIT;                   -- the SMS says "sent"
SELECT * FROM wallets;    -- Ama 300, Kwame 300. Total still 600
```

### C — Consistency: the rules still hold afterwards

Ama (GHS 300) tries to send GHS 800. This time the app credits Kwame **first**:

```sql
START TRANSACTION;
UPDATE wallets SET balance = balance + 800 WHERE owner = 'Kwame';   -- succeeds
UPDATE wallets SET balance = balance - 800 WHERE owner = 'Ama';     -- ERROR 3819: CHECK fails
SELECT * FROM wallets, (SELECT SUM(balance) AS total FROM wallets) t;
```

**Look carefully:** Kwame has 1,100 and Ama still has 300. **Total: 1,400.** GHS 800
was created from nothing! A failed statement does **not** undo the rest of the
transaction by itself. The app (or you) must respond to the error:

```sql
ROLLBACK;
SELECT * FROM wallets;    -- Ama 300, Kwame 300. Total 600: consistent again
```

> **Lesson:** the `CHECK` constraint stopped Ama going negative, and `ROLLBACK`
> restored consistency. **Every app must ROLLBACK when any step fails.** If it had
> sent `COMMIT` instead, the bank would have printed money.

### I — Isolation: parallel transactions don't see each other's half-done work

Open a **second terminal** (**+** at the top right of the terminal panel), log in, and
`USE campusdb;`.

| Terminal A (the transfer) | Terminal B (someone checking balances) |
|---|---|
| `START TRANSACTION;` | |
| `UPDATE wallets SET balance = balance - 100 WHERE owner = 'Ama';` | |
| `UPDATE wallets SET balance = balance + 100 WHERE owner = 'Kwame';` | |
| | `SELECT * FROM wallets;` → still **300 / 300** |
| `COMMIT;` | |
| | `SELECT * FROM wallets;` → now **200 / 400** |

**What you should see:** B never saw the half-finished transfer. It saw "before", then
"after", never "in between". Type `exit` in Terminal B.

### D — Durability: once committed, it survives a crash

```sql
exit
```

```bash
labctl restart                                          # the "power cut"
mysql -u root -p -e "SELECT * FROM campusdb.wallets;"   # still 200 / 400
```

The committed transfer survived the restart. InnoDB wrote it to its log on disk
**before** saying "OK", so even a real crash can't undo it.

### ACID summary (copy into your notes)

| Letter | Property | Meaning | What you saw today |
|---|---|---|---|
| A | Atomicity | All steps or none | `ROLLBACK` undid both steps |
| C | Consistency | Rules still hold after | `CHECK` blocked the overdraft; `ROLLBACK` restored the total |
| I | Isolation | Parallel transactions don't interfere | Terminal B never saw the half-done transfer |
| D | Durability | Once confirmed, survives a crash | The transfer survived `labctl restart` |

---

## ✅ Check your understanding

In `my-work/lab08-notes.md`:

1. Write a query: the average score per programme (hint: JOIN `students` and `enrolments`, then `GROUP BY programme`).
2. Explain the "SELECT first" habit and why it matters for `UPDATE` and `DELETE`.
3. When would you use `LEFT JOIN` instead of `JOIN`? Give a CampusDB example.
4. In the Consistency test, why was the total 1,400 before the `ROLLBACK`? What must an app do when a step fails?
5. Give one real situation (not MoMo) that needs a transaction, and list its steps.

---

## 📤 Submit

```bash
labctl submit 8
```

## 🧠 Key terms from today

| Term | What it is | When you use it |
|---|---|---|
| `SELECT … WHERE … ORDER BY … LIMIT` | Read chosen rows, sorted | Every question you ask |
| `GROUP BY` + `COUNT/SUM/AVG` | One summary row per group | Reports, averages per course |
| `JOIN` / `LEFT JOIN` | Matching rows only / all rows from the left | With data / including "nothing found" |
| `INSERT` / `UPDATE` / `DELETE` | Add / change / remove rows | Daily data work, with WHERE |
| Transaction | Changes that succeed or fail together | Any multi-step real-world action |
| `COMMIT` / `ROLLBACK` | Make permanent / undo since START | End of every transaction |
| autocommit | Each statement commits on its own | The default outside a transaction |
| ACID | Atomicity, Consistency, Isolation, Durability | What makes a transaction trustworthy |
