# Lab 10 — Week 2 mock exam (20 questions)

**Covers labs 6–9 · 75 minutes · 20 marks (1 mark per question)**

This is practice for your real exam. Work alone and use the clock. Your lecturer will
tell you whether notes are allowed.

**Part B is marked automatically from your server**, so follow the names in each
question **exactly** (database, table and column names, file names).

---

## How to take the exam

1. In the terminal:
   ```bash
   labctl hello 10
   labctl start-lab 10       # type YES: resets the server AND creates your answer sheet
   ```
2. Open **`my-work/lab10-answers.md`** in the Explorer and type each answer after `>`.
   Save often with **Ctrl + S**.
3. At any time you can see your Part B score so far:
   ```bash
   labctl check 10
   ```
4. When you finish (or time is up):
   ```bash
   labctl submit 10
   ```

---

## Part A — Understanding (questions 1–12)

**1.** When a client sends `SELECT * FROM students`, which component actually reads the
data pages from disk?
- a) The client b) The optimiser c) The storage engine (InnoDB) d) The binary log

**2.** In the restaurant analogy, what is the **buffer pool**, and why does it make
queries faster?

**3.** Classify each statement as DDL, DML or DCL:
(i) `CREATE TABLE` (ii) `UPDATE` (iii) `GRANT` (iv) `DROP` (v) `SELECT` (vi) `ALTER`

**4.** What does `DELETE FROM students;` do? Name the `mysql` client option that would
have refused it, and the error number it gives.

**5.** In lab 6 you ran `SET GLOBAL max_connections = 200;`. After `labctl restart` it was
151 again. Explain why, and where a DBA puts a setting that must survive restarts.

**6.** Match each constraint to its CampusDB example:
`NOT NULL`, `UNIQUE`, `CHECK`, `DEFAULT` ↔ `email`, `last_name`, `status 'active'`, `score BETWEEN 0 AND 100`

**7.** Give **two** differences between a `PRIMARY KEY` and a `UNIQUE` constraint.

**8.** Using a Mobile Money transfer, explain what the **A** in ACID guarantees.

**9.** In lab 8's Consistency test, after the `CHECK` error the total money in the system
was 1,400 instead of 600. Why? What must an application do when one step of a
transaction fails?
- a) Nothing: MySQL undoes everything automatically
- b) Send `ROLLBACK`
- c) Send `COMMIT`
- d) Restart the server

**10.** Sunday: full backup. Monday, Tuesday, Wednesday: backups. The server fails on
Thursday morning. Which backups do you need to restore if the Mon–Wed backups were
**incremental**? And if they were **differential**?

**11.** State the **3-2-1** backup rule, and give a real example of each part for a
university.

**12.** In lab 9, student 10458 (Abena) was missing after the restore. Which number does
this illustrate, **RPO** or **RTO**? Define both.

---

## Part B — Practical (questions 13–20)

Work on your server (`mysql -u root -p`). Questions 13–19 are **auto-marked**, so use
these names exactly. In your answer sheet, note briefly what you did for each.

**13.** Create a database named **`exam_w2`**.

**14.** In `exam_w2`, create a table **`books`** with these columns and rules:

| Column | Type | Rule |
|---|---|---|
| `book_id` | `INT` | primary key |
| `title` | `VARCHAR(100)` | required (not null) |
| `isbn` | `VARCHAR(20)` | no two books may share an ISBN |
| `copies` | `INT` | required, defaults to **1**, may never be below 0 |

**15.** In `exam_w2`, create a table **`loans`**:

| Column | Type | Rule |
|---|---|---|
| `loan_id` | `INT` | primary key, numbered automatically by MySQL |
| `book_id` | `INT` | required, must be a book that exists in `books` |
| `borrower` | `VARCHAR(50)` | required |
| `loaned_on` | `DATE` | required |

**16.** Insert these three books, then insert **two loans**: one for book 1 and one for
book 3 (any borrower names and dates). **Do not change the copies numbers.**

| book_id | title | isbn | copies |
|---|---|---|---|
| 1 | Fundamentals of Database Systems | 978-0133970777 | 2 |
| 2 | Things Fall Apart | 978-0385474542 | 3 |
| 3 | Ghana Must Go | 978-1594204494 | 1 |

**17.** In **one transaction**, lend book 2 to **`Akosua Darko`** today: insert the loan
(use `CURDATE()` for the date) **and** reduce book 2's `copies` by 1. Commit it.
Paste your transaction into the answer sheet.

**18.** From the `$` prompt, back up the `exam_w2` database to the file
**`my-work/exam_w2_backup.sql`**.

**19.** Create a checksum of that backup named **`my-work/exam_w2_backup.sha256`**.
(Hint: run `sha256sum` from **inside** the `my-work` folder.)

**20.** *(Marked by your lecturer.)* Write **one query** that lists the borrower, the book
title and the loan date for **every** loan, oldest first. Paste the query and its result.

---

*End of exam. Run `labctl check 10` to see your Part B score, save your answer sheet
(Ctrl + S), then run `labctl submit 10`.*
