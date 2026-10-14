# Lab 2 — Data vs information, and why spreadsheets fail

**Week 1 · Syllabus: Theory 1 (Data vs information) and Theory 2 (Why not just use Excel?) · Time: about 2 hours**

> **Goal:** turn raw data into information, then "break" a spreadsheet-style table
> and discover, with your own queries, the seven problems a DBMS was invented to solve.

---

## Before you start

```bash
labctl hello 2
labctl start-lab 2      # loads two ready-made databases for you (type YES)
mysql -u root -p
```

Your lecturer prepared two databases holding **the same facts about the same
students**, stored two different ways:

| Database | Stored like… | Library analogy |
|---|---|---|
| `sheet_demo` | One big shared spreadsheet: every cell is free text, no rules | A pile of photocopied notes |
| `campus_preview` | Proper relational tables with keys and rules | A tidy card catalogue |

> 💡 In week 1 you **read** data; in week 2 you'll build your own. You'll meet a few
> commands today (`GROUP BY`, `DISTINCT`) before they're formally taught: just type
> them and read the comment beside each one.

---

## Part 1 — Data vs information

### 📇 Know-how card: data and information

| | |
|---|---|
| **Data** | Raw facts with no context: `10452`, `Ama`, `78`. |
| **Information** | Data organised so it *means* something: "Student 10452, Ama Mensah, scored 78 in Database Administration." |
| **When it matters** | Decisions are made from information, never from raw data. A database's job is to store data so it can **reliably** become information. |
| **How** | You turn data into information with a **query**: you ask a question and the DBMS assembles the answer. |
| **Analogy** | Data is loose rice grains on the floor. Information is rice cooked into jollof and served on a plate. The database is the kitchen that keeps the ingredients labelled, stored and ready. |

### Step 1 — Raw data

```sql
USE campus_preview;
SELECT * FROM enrolments;      -- numbers and codes: data, not yet information
```

You see rows like `1 | 10452 | DBA401 | 2026-1 | 78`. Hard to read, isn't it?

### Step 2 — Information

```sql
-- Ask a real question: "What did student 10452 score, in which courses?"
SELECT CONCAT('Student ', s.student_id, ', ', s.first_name, ' ', s.last_name,
              ', scored ', e.score, ' in ', c.title) AS information
FROM students s
JOIN enrolments e ON e.student_id = s.student_id     -- link each score to its student
JOIN courses    c ON c.course_code = e.course_code   -- link each score to its course
WHERE s.student_id = 10452;
```

**What you should see:** three readable sentences about Ama. Same data, now
information. That is what every results portal does when you check your grades.

---

## Part 2 — Break the spreadsheet

Now look at the "shared Excel file":

```sql
USE sheet_demo;
SELECT * FROM results_sheet;
```

Read the 9 rows carefully. Then work through the problems below. For each one,
**run the query, read the output, and write one line in your notes** on what
went wrong.

### Problem 1 — Redundancy (the same fact typed many times)

```sql
-- How many times was each student's name and phone typed in?
SELECT student_name, COUNT(*) AS times_typed
FROM results_sheet
GROUP BY student_name;          -- GROUP BY = "make one pile per name, then count each pile"
```

Ama's name, phone and programme are typed **three times**. Every extra copy is
another place to make a mistake.

> **DBMS fix:** store each fact **once** and link to it. In `campus_preview`, Ama's
> phone lives in exactly one row of `students`; her three scores just *point* at her
> student ID.

### Problem 2 — Inconsistency (copies that disagree)

```sql
-- Which phone number is Ama's?
SELECT DISTINCT student_name, phone           -- DISTINCT = "hide duplicate rows"
FROM results_sheet
WHERE student_name LIKE '%Mensah%';           -- LIKE '%Mensah%' = "contains Mensah"

-- How many different ways was the programme typed?
SELECT DISTINCT programme FROM results_sheet;

-- And the lecturer's name?
SELECT DISTINCT lecturer FROM results_sheet;
```

**What you should see:** two different phone numbers for Ama (someone updated one
row and forgot the others), both `BSc IT` and `B.Sc IT`, and both `Dr Asante` and
`Dr. Asante`. Also find the student typed as both `Kwame Boateng` and `K. Boateng`.

> **DBMS fix:** one source of truth. Change Ama's phone in one place and every
> report sees the new number.

### Problem 3 — No integrity rules (anyone can type anything)

```sql
-- Which scores are not numbers?
SELECT row_no, student_name, course, score
FROM results_sheet
WHERE score NOT REGEXP '^[0-9]+$';       -- "score is not made only of digits"

-- Now try to calculate the class average
SELECT AVG(score) AS average_score FROM results_sheet;
SHOW WARNINGS;                           -- MySQL tells you what it had to guess
```

**What you should see:** `seventy` and an empty score. The average is **wrong**:
MySQL silently treated `seventy` and the blank as `0`, and `SHOW WARNINGS` admits it
(`Truncated incorrect DOUBLE value: 'seventy'`).

Try the fees too:

```sql
SELECT SUM(fees_paid_ghs) AS total_fees FROM results_sheet;
SHOW WARNINGS;                           -- '4,500' was read as 4!
```

Now try the same mistake in the **relational** database:

```sql
INSERT INTO campus_preview.enrolments (student_id, course_code, semester, score)
VALUES (10453, 'SWE403', '2026-1', 'seventy');
```

**What you should see:** `ERROR 1366 (HY000): Incorrect integer value: 'seventy'`.
The bad data never gets in.

> **DBMS fix:** **data types** and **constraints**. The `score` column only accepts
> whole numbers from 0 to 100. Analogy: the bouncer at the door checks every guest.

### Problem 4 — Concurrency (two people editing at once)

In a shared Excel file, if two lecturers open it, change Ama's score and save, one
change is silently lost. Watch how a DBMS handles it. You need **two terminals**:
click the **+** at the top right of the terminal panel to open a second one, and log
in to MySQL in both.

| Terminal A (Lecturer 1) | Terminal B (Lecturer 2) |
|---|---|
| `START TRANSACTION;` | |
| `UPDATE campus_preview.enrolments SET score = 80 WHERE enrol_id = 1;` | |
| | `UPDATE campus_preview.enrolments SET score = 90 WHERE enrol_id = 1;` ⏳ *it waits!* |
| `COMMIT;` (do this within 30 seconds) | ✅ *finishes immediately after A commits* |
| `SELECT score FROM campus_preview.enrolments WHERE enrol_id = 1;` | |

**What you should see:** Terminal B **waits** until A is finished. The DBMS **locks**
the row while A changes it, so changes happen one after the other, never on top of
each other. The final score is 90, and both changes were applied in order: nothing
was lost by accident. (`START TRANSACTION` and `COMMIT` are explained properly in lab 8.)

> **DBMS fix:** transactions and locking. Analogy: only one person may hold the
> catalogue card at a time; the next person waits at the desk.

Type `exit` in Terminal B, then go back to Terminal A.

### Problem 5 — Security (everyone sees everything)

```sql
SELECT student_name, fees_paid_ghs FROM sheet_demo.results_sheet;
```

Anyone who gets the spreadsheet file sees every student's fees, including lecturers
who have no reason to. A spreadsheet has one lock: the whole file.

> **DBMS fix:** per-user, per-table, even per-column permissions (week 3). A lecturer
> can be allowed scores but refused fees.

### Problems 6 and 7 — Recovery and scale

Read these; you'll practise them later.

| Problem | In a spreadsheet | How a DBMS solves it | Where you'll see it |
|---|---|---|---|
| Recovery | Laptop dies, file gone | Logs, backups, point-in-time restore | Labs 4 and 9 |
| Scale | Slows down past ~100,000 rows | Built for millions of rows, with **indexes** | Lab 4 (`EXPLAIN`) |

---

## Part 3 — Summary table (copy it into your notes and fill the last column)

| Problem in a spreadsheet | What happened in `sheet_demo` | How a DBMS solves it |
|---|---|---|
| Redundancy | | Store it once, link to it |
| Inconsistency | | One source of truth |
| No integrity rules | | Data types and constraints reject bad data |
| Concurrency | | Transactions and locking |
| Security | | Per-user, per-table permissions |
| Recovery | (not shown) | Logs, backups, point-in-time restore |
| Scale | (not shown) | Built for millions of rows with indexes |

---

## ✅ Check your understanding

Write in `my-work/lab02-notes.md`:

1. Give your own example of **data** and of the **information** made from it (not about students).
2. Fill the middle column of the summary table above from what you saw.
3. Why was the class average in Problem 3 wrong, and why is that **more dangerous** than an error message?
4. In Problem 4, why did Terminal B have to wait? What would a spreadsheet have done instead?

---

## 📤 Submit

```bash
exit                # leave MySQL first, so your SQL history is saved
labctl submit 2
```

## 🧠 Key terms from today

| Term | What it is | When you use it |
|---|---|---|
| Data | Raw facts with no context | Stored in the database |
| Information | Data organised to answer a question | What people actually use to decide |
| Query | A question you send to the DBMS (`SELECT …`) | Every time you want information |
| Redundancy | The same fact stored many times | Avoid it: store once, link |
| Inconsistency | Copies of a fact that disagree | The result of redundancy |
| Integrity | Data is correct and follows the rules | Enforced by types and constraints |
| Concurrency | Many users working at the same time | Handled by transactions and locks |
