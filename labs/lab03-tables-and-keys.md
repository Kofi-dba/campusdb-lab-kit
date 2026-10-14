# Lab 3 — The relational model: tables, rows, columns and keys

**Week 1 · Syllabus: Theory 4 (The relational model) · Time: about 2 hours**

> **Goal:** read a real relational database, identify its tables, columns, data types,
> primary keys and foreign keys, follow a relationship by hand, and watch
> **referential integrity** reject bad data.

---

## Before you start

```bash
labctl hello 3
labctl start-lab 3      # type YES
mysql -u root -p
```

```sql
USE campus_preview;
SHOW TABLES;            -- students, courses, enrolments
```

---

## Part 1 — Tables, rows, columns and data types

### 📇 Know-how card: the parts of a table

| Part | What it is | Example in `campus_preview` | Library analogy |
|---|---|---|---|
| **Table** (relation) | Holds one kind of thing | `students` | A shelf of one kind of item |
| **Row** (record, tuple) | One instance of that thing | Ama's row | One card in the catalogue |
| **Column** (field, attribute) | One property every row has | `last_name` | One labelled line on every card |
| **Data type** | The kind of value a column accepts | `INT`, `VARCHAR(50)` | "Write a number here", "max 50 letters here" |

**When you use this:** every time you design or read a database. Before you write
any query, you look at the table's structure first, the way you'd read a form's
labels before filling it in.

### Step 1 — Look at the structure

```sql
DESCRIBE students;       -- the columns, their types, and which one is the key
DESCRIBE enrolments;
```

How to read `DESCRIBE`:

| Column of the output | Meaning |
|---|---|
| `Field` | The column name |
| `Type` | The data type, e.g. `int`, `varchar(50)` |
| `Null` | `NO` = a value is required |
| `Key` | `PRI` = primary key, `MUL` = part of a foreign key (many rows may share a value) |
| `Extra` | e.g. `auto_increment` = MySQL numbers the rows for you |

### 📇 Know-how card: common data types

| Type | What it holds | When to use it | Example |
|---|---|---|---|
| `INT` | Whole numbers | IDs, counts, scores | `78` |
| `VARCHAR(n)` | Text up to *n* characters | Names, codes, emails | `'Mensah'` |
| `DATE` | A calendar date | Birthdays, payment dates | `'2026-09-01'` |
| `DECIMAL(10,2)` | Exact numbers with 2 decimals | **Money** (never use FLOAT for money) | `4500.00` |
| `TIMESTAMP` | Date and time | When a row was created | `2026-10-14 09:30:00` |

### Step 2 — See the full "blueprint" of a table

```sql
SHOW CREATE TABLE enrolments\G
```

(`\G` prints the result as a list instead of a wide table. Use it whenever the
output is too wide to read.)

Find the lines `PRIMARY KEY (enrol_id)`, the two `FOREIGN KEY … REFERENCES …`
lines, and `CHECK (score between 0 and 100)`. This is the exact SQL that built the
table; you'll write statements like it yourself in lab 7.

---

## Part 2 — Primary keys

### 📇 Know-how card: primary key (PK)

| | |
|---|---|
| **What it is** | A column (or columns) whose value is **unique** and **never empty** for every row. |
| **When you use it** | **Every** table needs one. It is how you point at exactly one row: "student 10452", never "the student called Ama" (there could be two Amas). |
| **How** | `student_id INT PRIMARY KEY` when creating the table. |
| **Analogy** | The unique barcode on each book. Or your **Ghana Card number**: one per person, never shared. |

### Step 3 — Find the primary keys

```sql
SELECT table_name, column_name
FROM information_schema.key_column_usage
WHERE table_schema = 'campus_preview' AND constraint_name = 'PRIMARY';
```

**What you should see:** `students.student_id`, `courses.course_code`, `enrolments.enrol_id`.

### Step 4 — Test the primary key rule

```sql
-- Try to add a second student with Ama's ID
INSERT INTO students VALUES (10452, 'Copy', 'Cat', '0200 000 000', 'BSc IT');
```

**What you should see:** `ERROR 1062 (23000): Duplicate entry '10452' for key 'students.PRIMARY'`.
Two cards can't share one barcode.

---

## Part 3 — Foreign keys and relationships

### 📇 Know-how card: foreign key (FK)

| | |
|---|---|
| **What it is** | A column that **points to the primary key of another table**, creating a relationship. |
| **When you use it** | Whenever one thing belongs to or refers to another: an enrolment belongs to a student and a course; a fee payment belongs to a student. |
| **How** | `FOREIGN KEY (student_id) REFERENCES students(student_id)` |
| **Analogy** | Writing someone's Ghana Card number on a form instead of copying out their whole life story. Or a library borrowing slip that points to a student barcode and a book barcode. |

### Step 5 — Follow a relationship by hand

```sql
-- Enrolment number 4: who is it, and which course?
SELECT * FROM enrolments WHERE enrol_id = 4;          -- student_id 10453, course DBA401
SELECT * FROM students   WHERE student_id = 10453;    -- follow the pointer: Kwame
SELECT * FROM courses    WHERE course_code = 'DBA401';-- follow the other pointer
```

You just did by hand what a **JOIN** does automatically:

```sql
SELECT e.enrol_id, s.first_name, s.last_name, c.title, e.score
FROM enrolments e
JOIN students s ON s.student_id  = e.student_id     -- follow the FK to students
JOIN courses  c ON c.course_code = e.course_code    -- follow the FK to courses
ORDER BY e.enrol_id;
```

### Step 6 — List every relationship in the database

```sql
SELECT table_name, column_name, referenced_table_name, referenced_column_name
FROM information_schema.key_column_usage
WHERE table_schema = 'campus_preview' AND referenced_table_name IS NOT NULL;
```

Read each row as: "`enrolments.student_id` **points to** `students.student_id`".

### 📇 Know-how card: one-to-many relationships

| | |
|---|---|
| **What it is** | One row in table A relates to **many** rows in table B. |
| **CampusDB examples** | One student → many enrolments. One course → many enrolments. One student → many fee payments. |
| **How you see it** | The FK always sits on the **"many"** side (`enrolments` holds `student_id`, not the other way round). |

```sql
-- How many enrolments does each student have? (one-to-many in numbers)
SELECT s.first_name, COUNT(e.enrol_id) AS enrolments
FROM students s
LEFT JOIN enrolments e ON e.student_id = s.student_id
GROUP BY s.student_id, s.first_name;
```

Diagram it in your notes like this:

```text
STUDENTS 1 ──────< many ENROLMENTS >────── 1 COURSES
"one student registers for many courses; one course has many students"
```

---

## Part 4 — Referential integrity: the bouncer at work

### 📇 Know-how card: referential integrity

| | |
|---|---|
| **What it is** | The rule that every foreign key value **must match an existing** primary key value. No pointing at things that don't exist. |
| **When it protects you** | When an app has a bug, someone types a wrong ID, or someone tries to delete a record that others depend on. |
| **How** | MySQL enforces it automatically once the `FOREIGN KEY` exists. You do nothing. |

### Step 7 — Try to break it

Run each statement on its own and copy the error into your notes.

```sql
-- (a) Enrol a student who doesn't exist
INSERT INTO enrolments (student_id, course_code, semester, score)
VALUES (99999, 'DBA401', '2026-1', 50);

-- (b) Enrol a real student in a course that doesn't exist
INSERT INTO enrolments (student_id, course_code, semester, score)
VALUES (10452, 'XYZ999', '2026-1', 50);

-- (c) Delete Ama, who still has enrolments pointing at her
DELETE FROM students WHERE student_id = 10452;
```

| Attempt | Expected error | Plain English |
|---|---|---|
| (a) | `ERROR 1452` … a foreign key constraint fails | "There is no student 99999 to point to" |
| (b) | `ERROR 1452` … a foreign key constraint fails | "There is no course XYZ999" |
| (c) | `ERROR 1451` Cannot delete or update a parent row | "Three enrolments still point at Ama; deleting her would leave orphans" |

> If any of these **succeeded**, something is wrong with your copy: run
> `labctl start-lab 3` and try again.

---

## ✅ Check your understanding

Write in `my-work/lab03-notes.md`:

1. Name the table, a row, and a column from `campus_preview`, using real values.
2. What is the difference between a primary key and a foreign key? Use the Ghana Card analogy.
3. What is referential integrity? Which of your three errors in Step 7 proves it?
4. Why does the foreign key sit in `enrolments` and not in `students`?
5. Why should money be stored as `DECIMAL(10,2)` and not as text (remember lab 2's `'4,500'`)?

---

## 📤 Submit

```bash
exit
labctl submit 3
```

## 🧠 Key terms from today

| Term | What it is | Analogy |
|---|---|---|
| Table / row / column | Kind of thing / one instance / one property | Shelf / card / line on the card |
| Data type | What a column accepts | "Numbers only" on a form box |
| Primary key | Unique, never-empty identifier | Ghana Card number |
| Foreign key | Points to a primary key elsewhere | Writing someone's Ghana Card number on a form |
| Referential integrity | FKs must point to rows that exist | The bouncer checks the guest list |
| One-to-many | One row relates to many rows in another table | One student, many enrolments |
| JOIN | Follows the FK pointers automatically | The librarian fetching both cards for you |
