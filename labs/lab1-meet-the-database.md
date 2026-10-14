# Lab 1 — Meet the database

**Goal:** get your MySQL server running and look around inside it. We don't build
anything yet: today you're the new librarian getting the building tour.

**Time:** about 60–90 minutes · **Marks:** 5%

**Start state:** a fresh server. If you've been experimenting, run
`labctl start-week 1` first.

---

## Step 1 — Open your codespace and log in

Follow `labs/00-getting-started.md` if you haven't yet. Then:

```bash
mysql -u root -p
```

Enter `ChangeMe!2026`.

> **What just happened?** You handed the librarian (the DBMS) your library card
> (username `root`) and PIN (password). That is **authentication**: proving who
> you are. The `-p` means "ask me for the password"; never type the password
> after `-p` on the command line, because it would be saved in your shell history.

## Step 2 — Explore what already exists

Type each line at the `mysql>` prompt and read the output before moving on.

```sql
SELECT VERSION();                    -- which version of MySQL is running
SHOW DATABASES;                      -- the sections (wings) of the library
USE mysql;                           -- walk into the system wing
SHOW TABLES;                         -- the shelves in this wing
SELECT user, host FROM mysql.user;   -- who holds a library card
```

**What you should notice:**

- `SHOW DATABASES` lists four system databases (`information_schema`, `mysql`,
  `performance_schema`, `sys`). These are the library's *staff-only* records:
  the catalogue of the catalogue. You never store your own data in them.
- `mysql.user` shows accounts that came with the server, such as
  `debian-sys-maint`, `mysql.session`, `mysql.sys` and `root`. Each is a library
  card. The `host` column says which door the card works at, e.g. `localhost`
  means "only from inside this building".

## Step 3 — Look at the server's settings file

Type `exit` to leave MySQL. At the `$` prompt:

```bash
grep -v '^#' /etc/mysql/mysql.conf.d/mysqld.cnf | grep -v '^$'
```

Find `bind-address = 127.0.0.1`. This means the server only listens to
connections from the same machine.

> **Analogy:** the library's front door faces an inner courtyard, not the main
> road. Only people already inside the campus can reach it. In week 4 you'll see
> why that matters.

## Step 4 — See the DBMS working as the gatekeeper

Try to read a data file directly, *without* going through MySQL:

```bash
ls /var/lib/mysql
```

You get `Permission denied`. Your files are there, but only the `mysql` service
may touch them. Every application must ask the DBMS, which is exactly why the
DBMS can enforce security, integrity and backups.

> **Analogy:** you can't walk into the closed stacks. You hand a request slip to
> the librarian, who checks your card, fetches the book, and logs the loan.

## Step 5 — Generate your evidence

```bash
labctl check 1
```

## Submit (5%)

1. `my-work/evidence/lab1_<username>.txt`
2. Screenshot of `SELECT VERSION();` and `SHOW DATABASES;` in your terminal.
3. Three short answers (3 sentences each, your own words):
   - (a) What is a DBMS?
   - (b) What is the difference between a primary key and a foreign key?
   - (c) Look at the accounts list from Step 2. Why should nobody use `root` for daily work?

**Stretch (optional):** run `SELECT user, host, plugin FROM mysql.user;`. What is
the `plugin` column telling you? (Hint: it's *how* each card's PIN is checked.)
