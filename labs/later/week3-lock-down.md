# Lab 3 — Lock down CampusDB: users, roles and views

> 🚧 **Draft for week 3 — not part of the week 1–2 labs.** It will be renumbered
> (labs 11+) before week 3. Use `labctl start-week 3` to prepare your server; ignore
> the `labctl check` lines until your lecturer updates this sheet.


**Goal:** stop using the master key. Create one account per person, give each
account exactly the access their job needs through roles, and prove that
everything else is refused.

**Time:** about 2 hours · **Marks:** 5%

**Start state:** CampusDB built (end of Lab 2). If you missed Lab 2 or your
database is broken: `labctl start-week 3` (this builds CampusDB for you, with a
few extra students).

> **The big idea:** **Authentication** (AuthN) = *who are you?* Checked once, at
> login. **Authorisation** (AuthZ) = *what may you do?* Checked on **every single
> query**. At Kotoka, your passport gets you through immigration (AuthN); your
> boarding pass gets you onto one plane and one seat (AuthZ).

You'll need **two terminals** today: one stays logged in as root (the admin), the
other logs in as each staff member to test. Click the **+** at the top right of the
terminal panel to open a second one. Keep your commands in `my-work/lab3.sql`.

---

## Step 1 — Switch on password rules (as root)

```sql
INSTALL COMPONENT 'file://component_validate_password';
SET GLOBAL validate_password.policy = 'MEDIUM';
SET GLOBAL validate_password.length = 12;
SHOW VARIABLES LIKE 'validate_password%';
```

`MEDIUM` means at least 12 characters, with upper case, lower case, a digit and a
symbol. (If you see `ERROR 3529 … already loaded`, the component is already on;
carry on.)

## Step 2 — Create roles and give them privileges

```sql
CREATE ROLE role_registry, role_finance, role_lecturer;

GRANT SELECT, INSERT, UPDATE ON campusdb.students   TO role_registry;
GRANT SELECT, INSERT, UPDATE ON campusdb.enrolments TO role_registry;
GRANT SELECT                 ON campusdb.courses    TO role_registry;

GRANT SELECT, INSERT ON campusdb.fees     TO role_finance;
GRANT SELECT         ON campusdb.students TO role_finance;
```

> **Analogy:** roles are uniforms. The hospital doesn't brief the guard on every
> nurse; it says "blue scrubs may enter the ward". New nurse? Hand over blue scrubs.
> Nurse leaves? Take them back. One change, done.

Notice what is **missing**: nobody gets `DELETE`, nobody gets `DROP`, and the
registry can't see `fees` at all.

## Step 3 — A view for lecturers

Lecturers need names and scores, but must not see emails or fees.

```sql
CREATE VIEW campusdb.v_lecturer_scores AS
  SELECT e.enrol_id, s.student_id, s.first_name, s.last_name, e.course_code, e.score
  FROM campusdb.students s
  JOIN campusdb.enrolments e ON s.student_id = e.student_id;

GRANT SELECT ON campusdb.v_lecturer_scores TO role_lecturer;
GRANT SELECT (enrol_id), UPDATE (score) ON campusdb.enrolments TO role_lecturer;
```

> **Analogy:** a view is a window with frosted panes. Lecturers look through the
> clear panes (name, course, score); the rest of the room stays private. The
> second `GRANT` goes even narrower: lecturers may change **one column** (`score`),
> and may read `enrol_id` only so they can say *which* row to change.

## Step 4 — Create the staff accounts

```sql
CREATE USER 'efua_registry'@'localhost' IDENTIFIED BY 'Registry#Strong2026'
  PASSWORD EXPIRE INTERVAL 90 DAY FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 1;
CREATE USER 'kofi_finance'@'localhost' IDENTIFIED BY 'Finance#Strong2026'
  FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 1;
CREATE USER 'dr_asante'@'localhost' IDENTIFIED BY 'Lecturer#Strong2026'
  FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 1;

GRANT role_registry TO 'efua_registry'@'localhost';
GRANT role_finance  TO 'kofi_finance'@'localhost';
GRANT role_lecturer TO 'dr_asante'@'localhost';

SET DEFAULT ROLE ALL TO 'efua_registry'@'localhost',
                        'kofi_finance'@'localhost',
                        'dr_asante'@'localhost';
```

**Why `SET DEFAULT ROLE`?** In MySQL, granting a role is like handing someone a
uniform in a bag. Without `SET DEFAULT ROLE` they log in still wearing street
clothes and get refused everywhere. This is the #1 "my grants don't work!" mistake.

**Careful:** `FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 1` means three wrong
passwords locks the account for **1 day**. If you lock yourself out while testing,
unlock from the root terminal with:
`ALTER USER 'dr_asante'@'localhost' ACCOUNT UNLOCK;`

## Step 5 — Test as each user (second terminal)

```bash
mysql -u dr_asante -p campusdb
```

Password `Lecturer#Strong2026`, then:

```sql
SELECT * FROM v_lecturer_scores;                       -- works
UPDATE enrolments SET score = 70 WHERE enrol_id = 2;   -- works
SELECT * FROM fees;                                    -- ERROR 1142: denied
SELECT email FROM students;                            -- ERROR 1142: denied
DELETE FROM enrolments;                                -- ERROR 1142: denied
SELECT CURRENT_ROLE();                                 -- which uniform am I wearing?
exit
```

Now do the same for **`efua_registry`** and **`kofi_finance`**. For each user, find
**3 things that work and 3 that are denied** and record them in a table like this:

| User | Allowed (3) | Denied (3, with error code) |
|---|---|---|
| dr_asante | … | … |
| efua_registry | … | … |
| kofi_finance | … | … |

## Step 6 — Inspect, then revoke (root terminal)

```sql
SHOW GRANTS FOR 'dr_asante'@'localhost' USING role_lecturer;

-- Dr Asante leaves the university:
REVOKE role_lecturer FROM 'dr_asante'@'localhost';
ALTER USER 'dr_asante'@'localhost' ACCOUNT LOCK;
```

Try to log in as `dr_asante` in the other terminal. What message do you get?

Then **give the role back and unlock** so your evidence report is complete:

```sql
GRANT role_lecturer TO 'dr_asante'@'localhost';
SET DEFAULT ROLE ALL TO 'dr_asante'@'localhost';
ALTER USER 'dr_asante'@'localhost' ACCOUNT UNLOCK;
```

## Step 7 — Watch the password policy work

```sql
CREATE USER 'test'@'localhost' IDENTIFIED BY 'password';
```

Expected: `ERROR 1819 … Your password does not satisfy the current policy requirements`.

## Step 8 — Evidence and push

```bash
labctl check 3
```

Commit and push `my-work/`.

## Submit (5%)

1. Your allowed/denied table with screenshots for each user
2. `my-work/evidence/lab3_<username>.txt` (contains `SHOW GRANTS` for every user)
3. `my-work/lab3.sql`

**Homework:** design the roles for a Ghanaian hospital database with tables
`patients`, `diagnoses`, `prescriptions`, `billing` and four jobs: doctor,
pharmacist, cashier, receptionist. Justify each privilege in one line.
Read OWASP Top 10, A03 Injection, before week 4.
