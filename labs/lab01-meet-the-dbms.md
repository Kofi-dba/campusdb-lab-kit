# Lab 1 — Meet the DBMS

**Week 1 · Syllabus: Theory 3 (What a DBMS is) · Time: about 90 minutes**

> **Goal:** log in to your own MySQL server, look around inside it, and prove to
> yourself that the DBMS is the *only* way in to the data. No building yet: today
> you are the new librarian getting the building tour.

---

## Before you start

Every lab begins with the same two commands, typed at the `$` prompt in the
terminal:

```bash
labctl hello 1          # signs the attendance book (your lecturer sees it)
labctl start-lab 1      # puts your server in the right state for this lab (type YES)
```

> **Two prompts, two languages.**
> `$` means you are talking to **Linux** (the operating system).
> `mysql>` means you are talking to **MySQL** (the database).
> A Linux command typed at `mysql>` fails, and so does SQL typed at `$`.
> When something "doesn't work", check the prompt first.

---

## Part 1 — The DBMS and the client

### 📇 Know-how card: DBMS

| | |
|---|---|
| **What it is** | A **Database Management System** is software that stores data and controls *every* read and write to it. MySQL, PostgreSQL, SQL Server and Oracle are DBMSs. |
| **When you use it** | Whenever data must be shared by many people or apps, kept correct, kept secret, and survive a crash: banks, hospitals, GRA, MoMo, your university's results portal. |
| **How you use it** | You never open the data files yourself. You run a **client** program (`mysql`) that sends requests to the **server** (`mysqld`). |
| **Analogy** | You don't walk into the closed stacks of a library. You hand a request slip to the librarian, who checks your card, fetches the book and logs the loan. The DBMS is the librarian. |

### Step 1 — Two programs, not one

```bash
mysql --version          # the CLIENT: the program YOU type into
pgrep -a mysqld          # the SERVER: the program that guards the data, running in the background
```

**What you should see:** the client version (e.g. `mysql Ver 8.0.46…`) and a line
ending in `/usr/sbin/mysqld`. Two separate programs: the request slip and the librarian.

### Step 2 — Log in

```bash
mysql -u root -p
```

Password: `ChangeMe!2026` (nothing appears as you type; that's normal).

```text
-u root   = "my username is root"
-p        = "ask me for my password" (never type the password after -p: it would be
            saved in your command history for anyone to read)
```

> **What just happened?** You showed the librarian your **library card** (username)
> and **PIN** (password). This is called **authentication**: proving who you are.
> You'll study it properly in week 3.

---

## Part 2 — Look around

### 📇 Know-how card: the four system databases

| | |
|---|---|
| **What they are** | Databases MySQL creates for itself: `mysql` (accounts and settings), `information_schema` (a catalogue describing every database, table and column), `performance_schema` and `sys` (performance measurements). |
| **When you use them** | When you, as a DBA, need facts *about* the server: who has an account, which tables exist, what is slow. |
| **How you use them** | Read them with `SELECT`. **Never** store your own data in them. |
| **Analogy** | The library's staff-only office: the register of library cards, the catalogue of the catalogue, and the visitor counters. |

### Step 3 — Explore (type each line at `mysql>`, then read the output before moving on)

```sql
SELECT VERSION();                    -- which version of MySQL is running
SHOW DATABASES;                      -- the sections (wings) of the library
USE mysql;                           -- walk into the system wing
SHOW TABLES;                         -- the shelves in this wing
SELECT user, host FROM mysql.user;   -- who holds a library card
```

> 💡 Every SQL statement ends with `;`. If MySQL shows `->`, it is waiting for the
> rest of your statement: type `;` and press Enter.

**What you should see:**

- `SHOW DATABASES` lists exactly four databases: the staff office. Nothing of yours yet.
- `mysql.user` lists accounts such as `debian-sys-maint`, `mysql.infoschema`,
  `mysql.session`, `mysql.sys` and `root`.
- The `host` column says **which door the card works at**. `localhost` means "only
  from inside this building (this machine)".

### Step 4 — Ask the catalogue a question

```sql
SELECT schema_name FROM information_schema.schemata;   -- same list as SHOW DATABASES
SELECT COUNT(*) AS how_many_tables FROM information_schema.tables;
exit
```

> **Why does this matter?** `SHOW DATABASES` is a shortcut. Underneath, MySQL keeps a
> *table describing all the tables*. DBAs query `information_schema` constantly, and
> you'll use it in labs 3, 6 and 7.

---

## Part 3 — The DBMS is the only gate

### 📇 Know-how card: why apps never touch the data files

| | |
|---|---|
| **What it is** | Your data lives in files on disk (in `/var/lib/mysql`), but only the `mysql` server process may open them. |
| **Why** | One single gate is what makes **security** (check every request), **integrity** (enforce the rules), **concurrency** (stop two people overwriting each other) and **backup** possible. |
| **When it matters** | Always. If an app could edit the files directly, all four protections disappear. |

### Step 5 — Try to sneak into the stacks

At the `$` prompt (type `exit` first if you're still at `mysql>`):

```bash
ls /var/lib/mysql
```

**What you should see:** `Permission denied`. The data is right there, but you
(an ordinary user) can't touch it. Only the librarian can.

```text
   Student portal ─┐
   Finance app ────┼──►  DBMS (the librarian)  ──►  data files on disk
   Lecturer ───────┘       checks every request      (nobody else may touch)
```

### Step 6 — The server's settings file

```bash
grep -v '^#' /etc/mysql/mysql.conf.d/mysqld.cnf | grep -v '^$'
```

(`grep -v '^#'` hides comment lines, `grep -v '^$'` hides empty lines.)

Find `bind-address = 127.0.0.1`. It means the server only accepts connections
from this same machine.

> **Analogy:** the library's front door faces an inner courtyard, not the main road.
> Only people already inside the campus can reach it. Lab 4 explains why a DBA cares.

---

## ✅ Check your understanding

Answer in your own words in `my-work/lab01-notes.md` (right-click `my-work` ▸ New File):

1. What is a DBMS? Give the library analogy in one sentence.
2. Name the two programs you met in Step 1 and say what each one does.
3. Look at the accounts list from Step 3. Why should nobody use `root` for daily work?
4. In Step 5 you got `Permission denied`. Why is that a **good** thing?

**Stretch:** run `SELECT user, host, plugin FROM mysql.user;`. What do you think the
`plugin` column describes? (Hint: *how* each card's PIN is checked.)

---

## 📤 Submit

```bash
labctl submit 1
```

This writes `my-work/evidence/lab01_<you>.txt` (with the SQL you typed today) and
saves your `my-work/` folder to GitHub, where your lecturer can see it.

## 🧠 Key terms from today

| Term | What it is | Library analogy |
|---|---|---|
| DBMS | Software that stores data and controls every access to it | The librarian and the building |
| Client | The program you type requests into (`mysql`) | The request slip |
| Server | The background program that guards the data (`mysqld`) | The librarian |
| Database | A named collection of tables | One wing of the library |
| `information_schema` | Tables that describe all other tables | The catalogue of the catalogue |
| `bind-address` | Which network addresses the server listens on | Which street the front door faces |
