# Lab 2 — Build CampusDB

**Goal:** build the CampusDB database with keys and constraints, break the rules on
purpose to watch the database defend itself, then take a backup, destroy the
database, and bring it back.

**Time:** about 2 hours · **Marks:** 5%

**Start state:** no `campusdb` yet. If you missed Lab 1 or want a clean start:
`labctl start-week 2`.

> **Work in a file, not live.** Create `my-work/lab2.sql` (right-click `my-work` ▸
> New File). Paste or type each block there, save, and run it from MySQL with
> `SOURCE my-work/lab2.sql;`. If something goes wrong, fix the file and run it again.
> This is how real DBAs work: every change is a script you can re-run and review.

---

## Step 1 — Create the database and tables

Log in (`mysql -u root -p`) and run:

```sql
CREATE DATABASE campusdb;
USE campusdb;

CREATE TABLE students (
  student_id  INT PRIMARY KEY,
  first_name  VARCHAR(50)  NOT NULL,
  last_name   VARCHAR(50)  NOT NULL,
  email       VARCHAR(100) UNIQUE,
  programme   VARCHAR(50),
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE courses (
  course_code VARCHAR(10) PRIMARY KEY,
  title       VARCHAR(100) NOT NULL,
  credits     INT CHECK (credits BETWEEN 1 AND 6)
);

CREATE TABLE enrolments (
  enrol_id    INT AUTO_INCREMENT PRIMARY KEY,
  student_id  INT NOT NULL,
  course_code VARCHAR(10) NOT NULL,
  score       INT CHECK (score BETWEEN 0 AND 100),
  FOREIGN KEY (student_id)  REFERENCES students(student_id),
  FOREIGN KEY (course_code) REFERENCES courses(course_code)
);

CREATE TABLE fees (
  payment_id  INT AUTO_INCREMENT PRIMARY KEY,
  student_id  INT NOT NULL,
  amount_ghs  DECIMAL(10,2) NOT NULL,
  paid_on     DATE NOT NULL,
  FOREIGN KEY (student_id) REFERENCES students(student_id)
);

SHOW TABLES;
DESCRIBE enrolments;
```

> **Analogy:** `CREATE DATABASE` builds the Science wing. Each `CREATE TABLE`
> fits a shelf and prints the blank card template: which lines every card has
> (columns), what may be written on each line (data types), and the rules the
> bouncer at the door will check (constraints).

**Reading the order matters:** `enrolments` and `fees` point at `students`, so
`students` must exist first. You can't write a borrowing slip for a book that
isn't on the shelf yet.

## Step 2 — Add sample data

```sql
INSERT INTO students (student_id, first_name, last_name, email, programme) VALUES
  (10452,'Ama','Mensah','ama.m@campus.edu.gh','BSc IT'),
  (10453,'Kwame','Boateng','kwame.b@campus.edu.gh','BSc CS'),
  (10454,'Efua','Owusu','efua.o@campus.edu.gh','BSc IT');

INSERT INTO courses VALUES
  ('DBA401','Database Administration',3),
  ('NET402','Network Security',3);

INSERT INTO enrolments (student_id, course_code, score) VALUES
  (10452,'DBA401',78),(10453,'DBA401',65),(10454,'NET402',82);

INSERT INTO fees (student_id, amount_ghs, paid_on) VALUES
  (10452,4500.00,'2026-09-01'),(10453,2250.00,'2026-09-03');

SELECT * FROM students;
```

Notice you never typed `enrol_id`, `payment_id` or `created_at`.
`AUTO_INCREMENT` and `DEFAULT` filled them in for you.

## Step 3 — Break the rules on purpose

Run each statement **one at a time** and copy the error into your notes.

```sql
-- (a) Enrol a student who doesn't exist
INSERT INTO enrolments (student_id, course_code, score) VALUES (99999,'DBA401',50);

-- (b) A score of 150
INSERT INTO enrolments (student_id, course_code, score) VALUES (10452,'NET402',150);

-- (c) A second student 10452 with no last name
INSERT INTO students (student_id, first_name) VALUES (10452,'Copy');
```

What to expect:

| Attempt | Error code | Which rule stopped it |
|---|---|---|
| (a) | `ERROR 1452` … foreign key constraint fails | **Foreign key / referential integrity**: the slip points at a barcode that doesn't exist |
| (b) | `ERROR 3819` … Check constraint … is violated | **CHECK**: scores must be 0–100 |
| (c) | `ERROR 1364` Field 'last_name' doesn't have a default value *(or `1062` Duplicate entry)* | **NOT NULL** (and the **PRIMARY KEY** would also reject it). MySQL reports the first rule it trips over |

> **Analogy:** constraints are the bouncer at the club door. He checks every
> guest, whether they come through the app, the website, or a lecturer typing SQL
> at midnight, and he never gets tired.

**Try one more:** `DELETE FROM students WHERE student_id = 10452;` Why does MySQL
refuse? (Ama has enrolments and fees pointing at her. Deleting her would leave
orphaned slips.)

## Step 4 — Query and update

```sql
-- Who is enrolled in what, with their score?
SELECT s.first_name, s.last_name, e.course_code, e.score
FROM students s
JOIN enrolments e ON s.student_id = e.student_id;

-- Correct Ama's DBA401 score
UPDATE enrolments SET score = 80 WHERE enrol_id = 1;
SELECT * FROM enrolments WHERE enrol_id = 1;
```

**Your turn** (write these yourself, include them in your script):

1. List every student in `BSc IT`.
2. Show each student's name next to the total fees they've paid.
   (Hint: `JOIN fees`, `SUM(amount_ghs)`, `GROUP BY`.)
3. Which student has paid no fees at all? (Hint: `LEFT JOIN … WHERE f.payment_id IS NULL`.)

## Step 5 — A transaction (the MoMo test)

```sql
START TRANSACTION;
UPDATE fees SET amount_ghs = amount_ghs - 500 WHERE payment_id = 1;
SELECT * FROM fees;      -- you can see the change...
ROLLBACK;                -- ...now undo it
SELECT * FROM fees;      -- back to 4500.00
```

> **Analogy:** a MoMo transfer is two steps: debit Ama, credit Kwame. A
> transaction is the envelope that holds both. Either the envelope is delivered
> whole (`COMMIT`), or it is torn up and nothing happened (`ROLLBACK`).

## Step 6 — Back up, destroy, restore

Type `exit` to leave MySQL. These run at the **`$` Linux prompt**:

```bash
# 1. Take a backup into your work folder
mysqldump -u root -p campusdb > my-work/campusdb_backup.sql

# 2. Look inside: it's just SQL that rebuilds everything
head -40 my-work/campusdb_backup.sql

# 3. Simulate a disaster
mysql -u root -p -e "DROP DATABASE campusdb;"

# 4. Restore
mysql -u root -p -e "CREATE DATABASE campusdb;"
mysql -u root -p campusdb < my-work/campusdb_backup.sql

# 5. Prove it worked (should return 3)
mysql -u root -p -e "SELECT COUNT(*) FROM campusdb.students;"
```

> **Analogy:** `mysqldump` doesn't photocopy the shelves. It writes the
> *instructions* to rebuild them: "build a shelf called students, file a card for
> Ama…". That's a **logical** backup: slower, but readable and portable.

## Step 7 — Evidence and push

```bash
labctl check 2
```

Then commit and push `my-work/` (Source Control ▸ Commit ▸ Sync).

## Submit (5%)

1. `my-work/lab2.sql` (your full script, including the three "your turn" queries)
2. `my-work/evidence/lab2_<username>.txt`
3. Screenshots of the three errors from Step 3, each with one line explaining it
4. Screenshot of Step 6.5 returning `3`

**Homework:** one-page backup plan for CampusDB: backup type, how often, where the
copies live (3-2-1), RPO and RTO, and who tests a restore and how often.
