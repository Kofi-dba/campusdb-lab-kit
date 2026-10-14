# Lab 4 — Defend CampusDB: injection, encryption and auditing

**Goal:** see SQL injection succeed and fail with your own eyes, force every
connection to be encrypted, record who changed fee records, encrypt your backups,
and harden the server.

**Time:** about 2 hours · **Marks:** 5%

**Start state:** CampusDB with the roles and users from Lab 3. If you missed Lab 3
or anything is broken: `labctl start-week 4`.

Use two terminals again (root in one, test users in the other). Keep your SQL in
`my-work/lab4.sql`.

---

## Step 1 — Create a least-privilege account for the student portal (root)

Real applications should never connect as root. Our "student portal" only needs
to look students up.

```sql
CREATE USER 'portal_app'@'localhost' IDENTIFIED BY 'Portal#Lookup2026'
  FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LOCK_TIME 1;
GRANT SELECT ON campusdb.students TO 'portal_app'@'localhost';
```

Keep this account in mind: in Step 3 it is the wall that stops an attacker even
when the code is vulnerable.

## Step 2 — See injection safely inside MySQL

```sql
USE campusdb;
SET @input = "' OR '1'='1";

-- UNSAFE: look at the SQL text that gluing strings together would produce
-- (we only SELECT the text, we don't run it)
SELECT CONCAT("SELECT * FROM students WHERE last_name = '", @input, "'") AS built_query;

-- SAFE: a prepared statement, the input is bound as data
PREPARE stmt FROM 'SELECT * FROM students WHERE last_name = ?';
EXECUTE stmt USING @input;   -- 0 rows: no student is literally named  ' OR '1'='1
SET @input = 'Mensah';
EXECUTE stmt USING @input;   -- returns Ama
DEALLOCATE PREPARE stmt;
```

Look at `built_query`: the attacker's first `'` *closed* the programmer's string,
and `OR '1'='1'` became part of the SQL. Because `'1'='1'` is always true,
every row would match.

> **Analogy:** the request slip says "Fetch the record for student ____". The
> forger writes in the blank: *"Mensah, and also hand me the whole fees drawer."*
> A careless librarian reads the whole slip as orders. A prepared statement is
> the careful librarian: whatever is in the blank is **only ever a name to look up**.

## Step 3 — Attack a real (tiny) application

At the `$` prompt:

```bash
python3 demo/injection_demo.py
```

Password: `Portal#Lookup2026`. For each input below, the program runs the search
twice: once **unsafely** (string gluing) and once **safely** (parameterised).

| Type this | What to watch for |
|---|---|
| `Mensah` | Both versions return Ama. Normal use. |
| `' OR '1'='1` | **Unsafe returns every student.** Safe returns 0 rows. |
| `' UNION SELECT payment_id, student_id, amount_ghs, paid_on FROM fees #` | The unsafe query *tries* to steal fee records, but MySQL refuses with **ERROR 1142**: `portal_app` has no access to `fees`. Least privilege saved you even though the code was broken. |
| `' UNION SELECT user, host, plugin, authentication_string FROM mysql.user #` | Same: denied. Imagine if the app connected as root… |
| `'; DROP TABLE students; #` | Refused as a syntax error: the driver sends one statement at a time. And `portal_app` has no `DROP` anyway. |

Type `quit` to exit. Open `demo/injection_demo.py` and compare `unsafe_lookup`
with `safe_lookup`. The fix is **one line**.

**Write two sentences:** why did the safe version return nothing for `' OR '1'='1`?
And what would the `UNION … FROM fees` attack have done if the app connected as root?

## Step 4 — Force encrypted connections (root)

```sql
SHOW VARIABLES LIKE 'have_ssl';                 -- YES: MySQL made certificates at install
ALTER USER 'kofi_finance'@'localhost' REQUIRE SSL;
SET PERSIST require_secure_transport = ON;      -- refuse ALL unencrypted network connections
```

Now in the second terminal, connect **over the network** (TCP) to `127.0.0.1`:

```bash
mysql -u kofi_finance -p -h 127.0.0.1
```

At `mysql>` type `\s` and find the `SSL:` line. It shows the cipher, e.g.
`Cipher in use is TLS_AES_256_GCM_SHA384`. Type `exit`, then try to force an
unencrypted connection:

```bash
mysql -u kofi_finance -p -h 127.0.0.1 --ssl-mode=DISABLED
```

Expected: `ERROR 3159 … Connections using insecure transport are prohibited while --require_secure_transport=ON.`

**Why `-h 127.0.0.1`?** Without `-h`, MySQL uses the local *socket*, a private
pipe inside the machine that never touches the network, so MySQL treats it as
already secure. Always test encryption over TCP.

> **Analogy:** money moving between banks travels in an armoured van
> (encryption **in transit**, TLS). Money sitting in the bank is in the vault
> (encryption **at rest**). A vault is useless if the van is an open pickup.

## Step 5 — An audit trail for fees (root)

```sql
USE campusdb;

CREATE TABLE fees_audit (
  audit_id    INT AUTO_INCREMENT PRIMARY KEY,
  action      VARCHAR(10),
  payment_id  INT,
  old_amount  DECIMAL(10,2),
  new_amount  DECIMAL(10,2),
  changed_by  VARCHAR(100),
  changed_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_fees_insert AFTER INSERT ON fees FOR EACH ROW
  INSERT INTO fees_audit (action, payment_id, old_amount, new_amount, changed_by)
  VALUES ('INSERT', NEW.payment_id, NULL, NEW.amount_ghs, USER());

CREATE TRIGGER trg_fees_update AFTER UPDATE ON fees FOR EACH ROW
  INSERT INTO fees_audit (action, payment_id, old_amount, new_amount, changed_by)
  VALUES ('UPDATE', OLD.payment_id, OLD.amount_ghs, NEW.amount_ghs, USER());

CREATE TRIGGER trg_fees_delete AFTER DELETE ON fees FOR EACH ROW
  INSERT INTO fees_audit (action, payment_id, old_amount, new_amount, changed_by)
  VALUES ('DELETE', OLD.payment_id, OLD.amount_ghs, NULL, USER());
```

> **Why `USER()` and not `CURRENT_USER()`?** Inside a trigger, `CURRENT_USER()`
> returns the account that *created* the trigger (root), so every row would
> blame root. `USER()` returns the person who actually connected. Getting this
> wrong makes your CCTV record the building owner's face for every visitor.

Now make changes as two different people:

```bash
# second terminal, as finance (over TCP, encrypted)
mysql -u kofi_finance -p -h 127.0.0.1 campusdb
```
```sql
INSERT INTO fees (student_id, amount_ghs, paid_on) VALUES (10454, 3000.00, '2026-10-01');
UPDATE fees SET amount_ghs = 1 WHERE payment_id = 1;   -- denied: finance can't UPDATE
SELECT * FROM fees_audit;                              -- denied: finance can't see the audit
exit
```

Back in the root terminal:

```sql
UPDATE fees SET amount_ghs = 100 WHERE payment_id = 1;
SELECT * FROM campusdb.fees_audit;
```

You should see two rows: an `INSERT` by `kofi_finance@localhost` and an `UPDATE`
by `root@localhost`.

**Discuss:** finance users must have **no** privileges on `fees_audit`, or they
could erase their own tracks. That is *separation of duties*. Notice the trigger
still wrote kofi's row even though he can't touch `fees_audit`: triggers run with
their creator's privileges.

## Step 6 — Encrypted backup (Linux prompt)

Do this in separate steps so the two password prompts don't collide:

```bash
# 1. Dump and compress
mysqldump -u root -p campusdb > my-work/campusdb_full.sql
gzip -f my-work/campusdb_full.sql

# 2. Encrypt (choose a passphrase and remember it)
openssl enc -aes-256-cbc -pbkdf2 -salt \
  -in my-work/campusdb_full.sql.gz -out my-work/campusdb_full.sql.gz.enc

# 3. Delete the unencrypted copy
rm my-work/campusdb_full.sql.gz

# 4. Prove the encrypted file is unreadable
head -c 200 my-work/campusdb_full.sql.gz.enc | xxd | head
```

Now prove you can get it back (a backup you've never restored is a hope, not a backup):

```bash
openssl enc -d -aes-256-cbc -pbkdf2 \
  -in my-work/campusdb_full.sql.gz.enc -out my-work/restore.sql.gz
gunzip -f my-work/restore.sql.gz
mysql -u root -p -e "DROP DATABASE campusdb; CREATE DATABASE campusdb;"
mysql -u root -p campusdb < my-work/restore.sql
mysql -u root -p -e "SELECT COUNT(*) FROM campusdb.fees_audit;"
rm my-work/restore.sql
```

> **Key management matters more than the algorithm.** If you wrote the passphrase
> in a text file next to the backup, the lock is decoration.

## Step 7 — Harden the server

```bash
sudo mysql_secure_installation
```

When it asks for the root password, enter the current one. Read each prompt and
write one line on what it fixes:

| Prompt | Recommended answer | What it fixes |
|---|---|---|
| Change the password for root? | **Yes**: pick a long new one and store it safely | … |
| Remove anonymous users? | Yes | … |
| Disallow root login remotely? | Yes | … |
| Remove test database? | Yes | … |
| Reload privilege tables now? | Yes | … |

If you changed root's password, tell the helper: `labctl rootpw`.

## Step 8 — Evidence and push

```bash
labctl check 4
```

**Do not commit the `.enc` file's passphrase anywhere.** Commit and push `my-work/`.

## Submit (5%)

1. Screenshot of the prepared statement results (Step 2) and of the demo with
   `' OR '1'='1` and the denied `UNION` attack (Step 3), plus your two sentences
2. Screenshots of the `SSL:` status line and the refused `--ssl-mode=DISABLED`
   connection (Step 4)
3. `SELECT * FROM fees_audit;` showing rows by two different users (Step 5)
4. Screenshot of the successful restore from the encrypted backup (Step 6)
5. Your completed hardening table (Step 7)
6. `my-work/evidence/lab4_<username>.txt`
