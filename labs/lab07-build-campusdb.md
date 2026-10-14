# Lab 7 — Build CampusDB: tables and constraints (DDL)

**Week 2 · Syllabus: Theory 3 (Constraints) and Lab 2 (Build CampusDB) · Time: about 2 hours**

> **Goal:** build the CampusDB database yourself with `CREATE` statements, choose the
> right **constraint** for each rule, then break every rule on purpose and read how the
> database defends itself. CampusDB is the database you'll use for the rest of the course.

---

## Before you start

```bash
labctl hello 7
labctl start-lab 7      # type YES (no campusdb yet: you build it)
```

### 📇 Know-how card: work in a script file

| | |
|---|---|
| **What it is** | Writing your SQL in a `.sql` file and running the file, instead of typing live. |
| **When** | For anything longer than one line. This is how real DBAs work: every change is a script that can be reviewed, re-run and kept as a record. |
| **How** | Create `my-work/lab07.sql` (right-click `my-work` ▸ **New File**). Paste each block in, save (**Ctrl + S**), then at `mysql>` run `SOURCE my-work/lab07.sql;`. If something fails, fix the file and run it again. |

> 💡 To re-run the whole script from scratch, put `DROP DATABASE IF EXISTS campusdb;`
> as its first line.

```bash
mysql -u root -p
```

---

## Part 1 — Create the database

### 📇 Know-how card: CREATE DATABASE / USE

| | |
|---|---|
| **What it is** | `CREATE DATABASE` makes a new, empty database. `USE` makes it the one your next statements apply to. |
| **When** | Once per application or system: one for CampusDB, another for the library system, and so on. |
| **Analogy** | Building the Science wing, then walking into it. |

```sql
CREATE DATABASE campusdb;   -- build the wing
USE campusdb;               -- walk into it
```

---

## Part 2 — The constraints: rules the database enforces for you

### 📇 Know-how card: constraints

| Constraint | Rule it enforces | When to use it | CampusDB example |
|---|---|---|---|
| `PRIMARY KEY` | Unique and never empty | Every table, on the ID column | `student_id` |
| `FOREIGN KEY` | Must match a row in another table | Whenever a row refers to another table's row | `enrolments.student_id` must exist in `students` |
| `NOT NULL` | A value is required | Any field you can't do without | `last_name` |
| `UNIQUE` | No duplicates (but it isn't the main ID) | Natural identifiers like email, phone, ISBN | `email` |
| `CHECK` | The value must pass a test | Ranges and allowed values | `score BETWEEN 0 AND 100` |
| `DEFAULT` | Value used when none is given | Sensible starting values | `status DEFAULT 'active'` |
| `AUTO_INCREMENT` | MySQL numbers new rows for you | Internal IDs nobody types in | `enrol_id` |

> **Analogy:** constraints are the **bouncer at the club door**, checking every guest
> against the list. The bouncer never gets tired, so bad data never gets in, no matter
> which app or person tries.

**Why not just check in the app?** Because a database is used by many apps, scripts
and people. Rules in the database protect the data from **all** of them, including
the lecturer typing SQL at midnight.

---

## Part 3 — Build the four tables

Read the comment beside every line: each one tells you **which rule** the line creates.

### Table 1: `students`

```sql
CREATE TABLE students (
  student_id  INT PRIMARY KEY,                    -- PK: unique, never empty (the barcode)
  first_name  VARCHAR(50)  NOT NULL,              -- required
  last_name   VARCHAR(50)  NOT NULL,              -- required
  email       VARCHAR(100) UNIQUE,                -- no two students share an email
  programme   VARCHAR(50),                        -- optional (NULL allowed)
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- filled in automatically
);
```

### Table 2: `courses`

```sql
CREATE TABLE courses (
  course_code VARCHAR(10) PRIMARY KEY,            -- e.g. 'DBA401'
  title       VARCHAR(100) NOT NULL,
  credits     INT CHECK (credits BETWEEN 1 AND 6) -- CHECK: only 1 to 6 credits
);
```

### Table 3: `enrolments` (the "borrowing slips")

```sql
CREATE TABLE enrolments (
  enrol_id    INT AUTO_INCREMENT PRIMARY KEY,     -- MySQL numbers each slip: 1, 2, 3...
  student_id  INT NOT NULL,
  course_code VARCHAR(10) NOT NULL,
  score       INT CHECK (score BETWEEN 0 AND 100),
  FOREIGN KEY (student_id)  REFERENCES students(student_id),   -- must be a real student
  FOREIGN KEY (course_code) REFERENCES courses(course_code)    -- must be a real course
);
```

### Table 4: `fees`

```sql
CREATE TABLE fees (
  payment_id  INT AUTO_INCREMENT PRIMARY KEY,
  student_id  INT NOT NULL,
  amount_ghs  DECIMAL(10,2) NOT NULL,             -- money: exact, 2 decimal places
  paid_on     DATE NOT NULL,
  FOREIGN KEY (student_id) REFERENCES students(student_id)
);

SHOW TABLES;
```

> **Order matters.** `enrolments` and `fees` point at `students` and `courses`, so those
> must exist first. You can't write a borrowing slip for a book that isn't on the shelf yet.

---

## Part 4 — Add the sample data

```sql
INSERT INTO students (student_id, first_name, last_name, email, programme) VALUES
  (10452, 'Ama',   'Mensah',  'ama.m@campus.edu.gh',   'BSc IT'),
  (10453, 'Kwame', 'Boateng', 'kwame.b@campus.edu.gh', 'BSc CS'),
  (10454, 'Efua',  'Owusu',   'efua.o@campus.edu.gh',  'BSc IT');

INSERT INTO courses VALUES
  ('DBA401', 'Database Administration', 3),
  ('NET402', 'Network Security',        3);

INSERT INTO enrolments (student_id, course_code, score) VALUES
  (10452, 'DBA401', 78), (10453, 'DBA401', 65), (10454, 'NET402', 82);

INSERT INTO fees (student_id, amount_ghs, paid_on) VALUES
  (10452, 4500.00, '2026-09-01'), (10453, 2250.00, '2026-09-03');

SELECT * FROM students;
SELECT * FROM enrolments;
```

**Notice:** you never typed `created_at`, `enrol_id` or `payment_id`. `DEFAULT` and
`AUTO_INCREMENT` filled them in.

---

## Part 5 — Break every rule on purpose

Run each statement **one at a time** (live at `mysql>`, not in your script) and copy
the error into your notes.

```sql
-- (a) FOREIGN KEY: enrol a student who doesn't exist
INSERT INTO enrolments (student_id, course_code, score) VALUES (99999, 'DBA401', 50);

-- (b) CHECK: a score of 150
INSERT INTO enrolments (student_id, course_code, score) VALUES (10452, 'NET402', 150);

-- (c) PRIMARY KEY / NOT NULL: a second student 10452 with no last name
INSERT INTO students (student_id, first_name) VALUES (10452, 'Copy');

-- (d) UNIQUE: a new student who reuses Ama's email
INSERT INTO students (student_id, first_name, last_name, email)
VALUES (10460, 'Ama', 'Copy', 'ama.m@campus.edu.gh');

-- (e) CHECK on courses: a 9-credit course
INSERT INTO courses VALUES ('BIG999', 'Too Heavy', 9);
```

| Attempt | Expected error | Which rule stopped it |
|---|---|---|
| (a) | `ERROR 1452` … a foreign key constraint fails | **FOREIGN KEY**: the slip points at a barcode that doesn't exist |
| (b) | `ERROR 3819` Check constraint … is violated | **CHECK**: scores must be 0–100 |
| (c) | `ERROR 1364` Field 'last_name' doesn't have a default value *(or `1062` Duplicate entry)* | **NOT NULL** (and the **PRIMARY KEY** would reject it too). MySQL reports the first rule it trips over |
| (d) | `ERROR 1062` Duplicate entry … for key 'students.email' | **UNIQUE** |
| (e) | `ERROR 3819` Check constraint … is violated | **CHECK**: credits 1–6 |

---

## Part 6 — Change the structure safely: ALTER TABLE and DEFAULT

### 📇 Know-how card: ALTER TABLE

| | |
|---|---|
| **What it is** | Changes an existing table: add, change or remove columns or constraints, **without** losing the data already in it. |
| **When** | When requirements change: "we now need to record whether a student is active, suspended or graduated". |
| **Analogy** | Adding a new labelled line to every card already in the catalogue. |

```sql
-- New requirement: every student has a status, 'active' unless we say otherwise
ALTER TABLE students
  ADD COLUMN status VARCHAR(12) NOT NULL DEFAULT 'active';

SELECT student_id, first_name, status FROM students;   -- existing students got 'active'

-- A new student, without mentioning status
INSERT INTO students (student_id, first_name, last_name, email, programme)
VALUES (10455, 'Yaw', 'Asante', 'yaw.a@campus.edu.gh', 'BSc CS');

SELECT student_id, first_name, status, created_at FROM students WHERE student_id = 10455;
```

**What you should see:** Yaw's `status` is `active` and his `created_at` is now, though
you typed neither. That's `DEFAULT` at work.

### 📇 Know-how card: DROP TABLE

| | |
|---|---|
| **What it is** | Removes a table **and all its data**, instantly, with no undo. |
| **When** | Only for tables you are certain are no longer needed, **after** a backup. |

```sql
CREATE TABLE temp_test (id INT);   -- a throw-away table
DROP TABLE temp_test;              -- gone
DROP TABLE students;               -- try it: refused!
```

**What you should see:** `ERROR 3730` … Cannot drop table 'students' referenced by a
foreign key constraint. The foreign keys protect even the structure: you can't remove a
shelf that slips still point at.

---

## Part 7 — Inspect what you built

```sql
SHOW CREATE TABLE enrolments\G

SELECT table_name, constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'campusdb'
ORDER BY table_name, constraint_type;

exit
```

---

## ✅ Check your understanding

In `my-work/lab07-notes.md`:

1. Fill this table for CampusDB: for each of the 7 rules (PK, FK, NOT NULL, UNIQUE, CHECK, DEFAULT, AUTO_INCREMENT) give **one column** that uses it and **why**.
2. Your five errors from Part 5, each with one line in plain English.
3. What is the difference between `PRIMARY KEY` and `UNIQUE`? (Hint: how many per table? Can it be empty?)
4. Why did `DROP TABLE students` fail? Why is that good?
5. Why do we build `students` before `enrolments`?

---

## 📤 Submit

```bash
labctl submit 7
```

Your script `my-work/lab07.sql` is saved too.

## 🧠 Key terms from today

| Term | What it is | When you use it |
|---|---|---|
| `CREATE DATABASE` / `CREATE TABLE` | Build a wing / a shelf | Designing a new system |
| `ALTER TABLE` | Change a table without losing data | Requirements change |
| `DROP TABLE` / `DROP DATABASE` | Delete structure and data, no undo | Rarely, after a backup |
| Constraint | A rule the DBMS enforces on every change | Always: rules in the database, not just the app |
| `DEFAULT` | Value used when none is given | Status fields, timestamps |
| `AUTO_INCREMENT` | Automatic numbering | Internal IDs |
| `SOURCE file.sql` | Run a script file | Any change longer than one line |
