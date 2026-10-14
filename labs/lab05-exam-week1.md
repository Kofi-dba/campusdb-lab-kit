# Lab 5 — Week 1 mock exam (20 questions)

**Covers labs 1–4 · 60 minutes · 20 marks (1 mark per question)**

This is practice for your real exam. Treat it like the real thing: work alone, in
silence, and use the clock. Your lecturer will tell you whether notes are allowed.

---

## How to take the exam

1. In the terminal:
   ```bash
   labctl hello 5
   labctl start-lab 5        # type YES: resets the server AND creates your answer sheet
   ```
2. In the Explorer (left), open **`my-work/lab05-answers.md`**.
3. Type each answer on the line that starts with `>`. Save often with **Ctrl + S**.
4. For **Part B** you work on your server. Paste the query you ran *and* the result.
5. When you finish (or time is up):
   ```bash
   labctl submit 5
   ```

---

## Part A — Understanding (questions 1–15)

**1.** Which statement best describes a DBMS?
- a) A spreadsheet program that stores tables
- b) Software that stores data and controls every read and write to it
- c) A backup file that holds a copy of the data
- d) The network cable between the app and the server

**2.** In lab 1, `ls /var/lib/mysql` returned `Permission denied`. Why is this a **good** thing?
- a) It means MySQL is broken and must be reinstalled
- b) It hides the data from the DBA
- c) Only the server process may touch the data files, so every request passes through one gate that checks it
- d) It makes the server faster

**3.** Classify each item as **data** or **information**:
(i) `78` (ii) `"Ama Mensah scored 78 in Database Administration"` (iii) `0244 123 456`

**4.** In `sheet_demo`, Ama's phone number was stored as both `0244 123 456` and
`0201 555 777`. This spreadsheet problem is called:
- a) Concurrency b) Inconsistency c) Scale d) Recovery

**5.** In lab 2, `SELECT AVG(score)` on the spreadsheet table gave a wrong answer without
an error. Explain **why** in one or two sentences, and name the DBMS feature that prevents it.

**6.** In lab 2, Problem 4, Terminal B had to **wait** before its `UPDATE` finished. What was
the DBMS doing, and which spreadsheet problem does this solve?

**7.** Which data type should store a fee of GHS 4,500.00?
- a) `VARCHAR(12)` b) `INT` c) `DECIMAL(10,2)` d) `FLOAT`

**8.** Explain the difference between a **primary key** and a **foreign key**. Use the
Ghana Card analogy.

**9.** Which error do you get when you insert an enrolment for student `99999`, who does not exist?
- a) `ERROR 1062` Duplicate entry
- b) `ERROR 1452` a foreign key constraint fails
- c) `ERROR 1366` Incorrect integer value
- d) `ERROR 1142` command denied

**10.** In `campus_preview`, in which table does the foreign key `student_id` sit, and why there?

**11.** What is **referential integrity**?

**12.** In the output of `DESCRIBE students`, what does `PRI` in the `Key` column mean?
- a) The column is private b) The column is the primary key c) The column has priority d) The column is printed first

**13.** Scenario: *"The results portal is very slow on the day results are released."*
Which DBA duty handles this, and which command from lab 4 would you use first?

**14.** `bind_address = 127.0.0.1` means:
- a) The server accepts connections from any computer on the internet
- b) The server only accepts connections from the same machine
- c) The server has no password
- d) The server listens on port 127

**15.** Name **four** of the six duties of a DBA.

---

## Part B — Practical (questions 16–20)

Log in with `mysql -u root -p`. For each question, paste **the SQL you ran** and **the result**.

**16.** What is the exact version of your MySQL server?

**17.** In `campus_preview`, how many enrolments does student `10452` have? Write the query.

**18.** Write a query that lists the **first name** and the **course title** for every
enrolment with a score **above 75**, using JOINs. How many rows does it return?

**19.** Run:
```sql
EXPLAIN SELECT * FROM campus_preview.students WHERE phone = '0277 888 999';
```
What is the value of `type`? What does it mean, and why does MySQL do it this way?

**20.** Write a query that lists the accounts on your server that are **locked**.
Which accounts are they, and why are they locked?

---

*End of exam. Save your answer sheet (Ctrl + S), then run `labctl submit 5`.*
