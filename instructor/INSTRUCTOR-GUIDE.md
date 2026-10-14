# Instructor guide — running the CampusDB labs online

This kit turns the Weeks 1–4 syllabus into four browser-based labs. Every student
gets a **private MySQL 8.0 server** in a GitHub Codespace: no installs, works on
weak laptops and Chromebooks, and each student has full root access (needed for
Weeks 3–4) without being able to damage anyone else's work.

> **Analogy for the setup:** the GitHub repository is the *blueprint* of a lab
> room. GitHub Classroom photocopies the blueprint for each student, and a
> codespace is the room actually built from it. Fix the blueprint once and every
> new room gets the fix.

---

## 1. What's in the kit

| Path | Purpose |
|---|---|
| `.devcontainer/` | The blueprint: Ubuntu 24.04 + MySQL 8.0 server, Python, OpenSSL, SQLTools extension. Root password set to the syllabus default `ChangeMe!2026` on first start. |
| `labs/00-getting-started.md` | Student onboarding (opens automatically in every new codespace) |
| `labs/lab1…lab4-*.md` | Student lab sheets, adapted from the syllabus for Codespaces, with analogies and expected outputs |
| `scripts/labctl.sh` | Student helper, available as the `labctl` command (details below) |
| `sql/00_clean.sql` | Resets the server to a fresh state |
| `sql/01_campusdb.sql` | CampusDB as it should be at the end of Lab 2 (6 students, 3 courses) |
| `sql/02_access_control.sql` | Roles, lecturer view and staff accounts as at the end of Lab 3 |
| `demo/injection_demo.py` | A tiny student-lookup "portal" with an unsafe and a safe query, for Lab 4 |
| `my-work/` | Where students save scripts, backups and evidence; they push it to GitHub |

### `labctl` in one table

| Command | What it does | When students use it |
|---|---|---|
| `labctl doctor` | Checks MySQL is running and root login works | First thing when anything is odd |
| `labctl start-week N` | Resets the server to the **start** of week N (1–4) | Missed a lab, broke something, joined late |
| `labctl check N` | Writes `my-work/evidence/labN_<github-user>.txt` with the state of their server, stamped with GitHub username, codespace name and time | End of every lab, for submission |
| `labctl snapshot` / `restore-snapshot` | Saves/restores a copy of `campusdb` into `my-work/snapshots/` | Before risky experiments; before rebuilding a codespace |
| `labctl rootpw` | Updates the root password the helper uses | After `mysql_secure_installation` in Lab 4 |

`start-week` is the single most useful feature for online teaching. In a physical
lab, a student who missed week 2 sits next to a friend. Online they fall behind
permanently. With `labctl start-week 3` they're caught up in 10 seconds and can do
Lab 3 with everyone else (then go back to Lab 2 later).

---

## 2. One-time setup (about 45 minutes)

### Option A — GitHub Classroom (recommended)

Best for a class under 30: you get a dashboard of who has accepted, each student's
repo is private to them and you, and codespace usage is billed to your classroom
organisation instead of students' personal quotas.

1. **Apply for GitHub Teacher benefits** at <https://education.github.com/> (free,
   needs proof you teach). Approval can take a few days, so do this first.
2. **Create a free GitHub organisation** for the course, e.g. `dba401-2026`.
3. **Upload this kit as a repository** in that organisation (e.g.
   `campusdb-labs`). On the repo page: **Settings ▸ General ▸ tick "Template repository"**.
4. **Create a classroom** at <https://classroom.github.com> linked to the organisation.
5. **Enable Codespaces for the classroom** (Classroom settings ▸ GitHub Codespaces).
   GitHub then limits codespaces to 2-core machines automatically, which is all
   this lab needs.
6. **Create one assignment**, "CampusDB Labs", individual, from the
   `campusdb-labs` template, **private** repos, supported editor **GitHub Codespaces**.
   Use one assignment for all four weeks: students keep one codespace and one
   repo, and `my-work/` builds up across the block.
7. Copy the **invitation link** and post it on your course page with
   `labs/00-getting-started.md`.

### Option B — No Classroom (quickest)

Make the repo public (or invite students), mark it as a template, and tell
students to click **Use this template ▸ Open in a codespace**. Usage then comes
from each student's personal free allowance, so you get no dashboard, and you
collect evidence files by upload instead.

### Codespaces hours: will students run out?

- A codespace on GitHub Classroom is charged to the classroom organisation. GitHub
  gives verified teachers a free monthly allowance, which GitHub estimates covers a
  class of about 50 with 5 assignments a month on 2-core machines.
- On personal accounts (Option B), free accounts get a monthly allowance of core
  hours (about 60 hours a month on a 2-core machine), and verified students get
  180 core hours (about 90 hours on 2 cores).
- Four 2-hour labs plus self-study is roughly 20–30 hours a month, well inside
  either allowance, **if students stop their codespace when done**. Codespaces
  also stop by themselves after 30 minutes idle.

Check the current figures on GitHub's pages before the course starts; they change.

### Optional: prebuilds

The first launch takes 2–4 minutes while the container builds. You can enable a
**prebuild** (repo Settings ▸ Codespaces ▸ Set up prebuild) so codespaces open in
under a minute. It costs a little storage. For under 30 students it's nice but not
essential, as long as students create their codespace *before* Lab 1 (see §4).

---

## 3. Your dry run (do this before week 1, about 2 hours)

I could not run MySQL in the environment where this kit was written, so every
script was written and reviewed carefully but **not executed against a live
server**. Run through it once yourself in your own codespace. It's also your
best lab preparation.

- [ ] Open a codespace from the template. `labctl doctor` shows three `[ok]`.
- [ ] `mysql -u root -p` with `ChangeMe!2026` works.
- [ ] Lab 1 end to end; `labctl check 1` writes an evidence file.
- [ ] Lab 2 end to end, including backup → drop → restore. Note which error code
      attempt (c) gives on your build.
- [ ] `labctl start-week 3` rebuilds CampusDB; then Lab 3 end to end.
      Confirm `SET DEFAULT ROLE` makes the denied/allowed results match the sheet.
- [ ] `labctl start-week 4`; then Lab 4 end to end. Specifically confirm:
  - [ ] `mysql -u kofi_finance -p -h 127.0.0.1` connects (see troubleshooting if
        it says Access denied)
  - [ ] `python3 demo/injection_demo.py` connects as `portal_app`
  - [ ] the audit trail shows `kofi_finance@localhost` for the INSERT
- [ ] `labctl start-week 1` returns everything to a clean server.
- [ ] Stop the codespace, reopen it, check MySQL restarted by itself.

If anything misbehaves, the fix usually goes in one file (`labctl.sh` or a
`sql/*.sql` script). Fix it in the template repo *before* students accept the
assignment, because each student gets a copy at the moment they accept.

---

## 4. Running each online lab session

### The week before Lab 1: the "ticket in"

Losing Lab 1 to GitHub sign-ups, forgotten passwords and slow first builds is the
#1 risk of online labs. Make it homework instead:

> **Due 48 hours before Lab 1:** accept the assignment, open your codespace, run
> `labctl doctor`, and upload a screenshot showing three green `[ok]` lines.

Chase non-submitters individually. By lab day you know everyone can get in.

### A 2-hour online lab, minute by minute

| Time | What happens | Why |
|---|---|---|
| 0:00–0:10 | Everyone opens their codespace and runs `labctl doctor`. Poll: "green / stuck". Stuck students go to a help breakout room with you or a TA. | Catches broken environments before teaching starts |
| 0:10–0:25 | You screen-share and demo the **first two steps** live in your own codespace. Narrate the library analogy as you go. | Students copy a working pattern, not a document |
| 0:25–1:30 | Breakout rooms of 4–5 students. Each room has a rotating **lab captain** who screen-shares while the others follow on their own codespaces. Students post blockers in a single help channel/thread; you rotate through rooms every 10–15 minutes. | Peer help scales; the captain role keeps rooms from going silent |
| 1:30–1:45 | Back in the main room: one room shows their trickiest error and how they fixed it. | Errors are the content (especially Lab 2 Step 3 and Lab 3 Step 5) |
| 1:45–2:00 | Everyone runs `labctl check N`, commits and pushes. Exit poll: "finished / need more time". | Evidence exists before students leave |

**Low-bandwidth tip:** a codespace is light on data, as it sends text, not video.
The video call is the heavy part. Ask students to turn cameras off in breakout
rooms and let the captain share their screen.

### What to demo live each week

| Lab | Demo in the first 15 minutes | The "aha" moment to make sure everyone sees |
|---|---|---|
| 1 | Log in, `SHOW DATABASES`, `SELECT user, host FROM mysql.user` | `ls /var/lib/mysql` → Permission denied: the DBMS is the only gate |
| 2 | Create `students`, insert Ama, then break a rule | The three errors in Step 3, and the backup → `DROP` → restore |
| 3 | Create one role and one user; forget `SET DEFAULT ROLE` on purpose, show it fail, then fix it | Same SQL, different user → denied (ERROR 1142) |
| 4 | Run `injection_demo.py` with `' OR '1'='1` | The `UNION … FROM fees` attack blocked by least privilege, even though the code was vulnerable |

---

## 5. Marking with the evidence files

Each `labN_<user>.txt` starts with the GitHub username, codespace name and UTC
time, and ends with a short integrity stamp. It's not cryptographic proof (a
determined student could edit it), but it makes copy-paste between students
obvious: two students' files with identical timestamps or codespace names is a
conversation to have. Use the screenshots and written answers for the
"Understanding" part of the rubric.

| Lab | Check in the evidence file |
|---|---|
| 1 | Version 8.0.x; the four system databases; default accounts listed |
| 2 | Four tables; row counts; constraints include PRIMARY KEY, UNIQUE, CHECK and FOREIGN KEY; a backup file listed |
| 3 | `validate_password.policy = MEDIUM`, length 12; three roles; `role_edges` maps each user to one role; `SHOW GRANTS` contains no DELETE/DROP |
| 4 | `require_secure_transport = ON`; `kofi_finance` ssl_type `ANY`; three triggers on `fees`; `fees_audit` rows by at least two different users; `portal_app` has only SELECT on students; 0 anonymous accounts, 0 remote root, no `test` DB; an `.enc` file listed |

**Security-thinking marks (rubric 2/10):** reward students who notice things the
sheet doesn't say, such as the `debian-sys-maint` account in Lab 1, that `efua_registry`
can't see `fees` at all, or that the encrypted backup's passphrase must not be
committed to Git.

---

## 6. Changes from the syllabus (so your lecture matches the labs)

| Syllabus | Lab kit | Why |
|---|---|---|
| Lab 1: install MySQL or `docker run …` | Open a codespace; MySQL is pre-installed | Online and zero-install. Lab 1 instead explores the config file and the data directory permissions |
| Lab 2 error (c): "PK / NOT NULL error" | Sheet warns it may show **ERROR 1364** (no default for `last_name`) rather than 1062 | MySQL reports the first rule it hits; students otherwise think they did it wrong |
| Lab 3: lockout settings | Added how to unlock, and a note that `PASSWORD_LOCK_TIME 1` = **one day** | Students testing denied logins will lock themselves out |
| Lab 3 Step 6: revoke and lock Dr Asante | Then re-grant and unlock | So `labctl check 3` shows a complete picture and Lab 4 works |
| Lab 4 audit trigger uses `CURRENT_USER()` | Uses **`USER()`**, plus an INSERT trigger | Inside a trigger, `CURRENT_USER()` returns the trigger's *definer* (root), so every audit row would blame root. The syllabus demo hides this because root makes the change. With `USER()` and kofi inserting a payment, students see the real actor. **Worth correcting in the Week 4 lecture slide too.** |
| Lab 4 encrypted backup: one pipeline `mysqldump … \| gzip \| openssl enc -aes-256-cbc …` | Split into steps | In a pipeline, MySQL's password prompt and OpenSSL's passphrase prompt fire at the same time and garble each other. (The PDF also shows `-aes256-cbc` due to a line break; the correct flag is `-aes-256-cbc`.) |
| Lab 4 injection: inside MySQL only | Plus `injection_demo.py`, a real Python app connecting as a least-privilege `portal_app` account | Shows defence in depth: parameterised queries fix the code; least privilege limits the damage when code is wrong |
| Lab 4: `mysql_secure_installation` on a fresh server | Run on the student's own server, with a "what it fixes" table | One server per student; the table makes it assessable |
| Lab 4: `kofi_finance` `REQUIRE SSL` | Sheet uses `-h 127.0.0.1` for all later kofi logins | After `REQUIRE SSL`, socket logins (no `-h`) are refused for that user, which confuses students |
| `start-week 3/4` data | 6 students, 3 courses (syllabus has 3 and 2) | Richer JOIN/GROUP BY results. Students who build it themselves in Lab 2 still get the syllabus's 3 rows |

---

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Can't connect to local MySQL server through socket` | Codespace woke up but MySQL didn't start | `sudo service mysql start`, then `labctl doctor`. Persistent? `sudo tail -n 30 /var/log/mysql/error.log` |
| `labctl: command not found` | Post-create script didn't finish | `bash .devcontainer/post-create.sh` |
| Student's grants "don't work" | Forgot `SET DEFAULT ROLE ALL TO …` | Run it, then log out and back in. Check with `SELECT CURRENT_ROLE();` |
| `ERROR 3955 … Access denied, account is blocked for 1 day(s)` | 3 wrong passwords | As root: `ALTER USER 'x'@'localhost' ACCOUNT UNLOCK;` |
| `Access denied for user 'kofi_finance'@'localhost'` with `-h 127.0.0.1` despite the right password | Server resolved 127.0.0.1 to the IP, not to `localhost` (happens if `skip_name_resolve` is ON) | Check `SHOW VARIABLES LIKE 'skip_name_resolve';`. If ON, create the account as `'kofi_finance'@'127.0.0.1'` too, or remove that setting from `/etc/mysql/mysql.conf.d/` |
| Kofi can't log in without `-h` after Lab 4 Step 4 | `REQUIRE SSL`; the socket isn't SSL | Expected. Always use `-h 127.0.0.1` for kofi |
| `Access denied for user 'root'` after Lab 4 | Root password changed in `mysql_secure_installation` | Use the new password; run `labctl rootpw` |
| Student forgot the new root password | — | `labctl start-week` won't help (it needs root). Delete the codespace and create a new one; their pushed `my-work/` comes back from GitHub. Then `labctl start-week 4` |
| Codespace deleted / rebuilt, work gone | Server data lives inside the codespace | `my-work/` is safe if pushed. Rebuild state with `labctl start-week N` or `labctl restore-snapshot` |
| SQLTools sidebar asks to install a driver | First use of the extension | Click install; it's optional, as the terminal does everything |
| Very slow codespace | Machine type > 2 cores blocked, or browser tab overload | Close other tabs; the 2-core machine is enough for this lab |

---

## 8. Ghanaian data protection note

CampusDB uses **invented** names and data only. Remind students never to load real
student or patient data into lab servers, and use that as a hook for the Data
Protection Act, 2012 (Act 843) discussion: the hardening checklist is exactly the
"appropriate technical measures" the Act expects data controllers to take.
