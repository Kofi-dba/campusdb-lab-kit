# Instructor guide — running the CampusDB labs online

Every student gets a **private MySQL 8.0 server** in a GitHub Codespace: no installs,
works on weak laptops, full root access, and nobody can damage anyone else's work.

> **Analogy:** your template repository is the *blueprint* of a lab room. Each
> student photocopies the blueprint into their own repository, and their codespace is
> the room built from it.

---

## 1. What's in the kit

| Path | Purpose |
|---|---|
| `.devcontainer/` | The blueprint: Ubuntu 24.04 + MySQL 8.0, root password `ChangeMe!2026` |
| `labs/00-getting-started.md` | Student onboarding: own repo, add you as collaborator, the lab routine |
| `labs/lab01…lab04` | **Week 1** labs (syllabus week 1, Theories 1–5) |
| `labs/lab05-exam-week1.md` | **Week 1 mock exam**: 15 written + 5 practical questions |
| `labs/lab06…lab09` | **Week 2** labs (syllabus week 2, Theories 1–5) |
| `labs/lab10-exam-week2.md` | **Week 2 mock exam**: 12 written + 8 practical (7 auto-marked) |
| `labs/answer-sheets/` | Blank answer sheets, copied into `my-work/` by `labctl start-lab 5` / `10` |
| `labs/later/` | Week 3–4 drafts (access control, defence), to be renumbered as labs 11+ |
| `scripts/labctl.sh` | The student helper, available as `labctl` |
| `sql/` | Scripts behind `labctl start-lab` (clean server, week 1 samples, CampusDB) |
| `instructor/roster.py` | **Your class roster**: who signed in, who submitted what |

**Answer keys are NOT in this repository**, because the template is public. Keep them
private and never upload them here.

### Every lab follows the same "know-how" pattern

Each concept gets a **know-how card** (What it is / When you use it / How / Analogy),
then commented commands, then **"What you should see"**, then questions, then a
key-terms table. This mirrors the syllabus so lecture and lab use the same words.

### `labctl` commands

| Command | What it does |
|---|---|
| `labctl hello N` | Writes a timestamped line to `my-work/attendance.log` and uploads it |
| `labctl start-lab N` | Resets the server to the start of lab N (1–10) |
| `labctl check N` | Writes `my-work/evidence/labNN_<user>.txt` (server state + the SQL they typed) |
| `labctl submit N` | `check N`, then uploads `my-work/` to the student's GitHub repo |
| `labctl update` | Pulls your newest lab sheets and scripts into a student's copy |
| `labctl restart` | Restarts MySQL safely (used in labs 6 and 8) |

### What `start-lab` loads

| Labs | Server state |
|---|---|
| 1 | Empty server |
| 2–7 | + `sheet_demo` (messy spreadsheet table) and `campus_preview` (relational version) |
| 8–10 | + `campusdb` with 6 students, 3 courses, 7 enrolments, 4 fee payments |

---

## 2. Monitoring your class

Students' codespaces are private, like their own laptops, so you can't look inside
them. Instead, each student keeps an **attendance book** in their own repository, and
`roster.py` reads all of them for you.

```text
Student's codespace                    Student's private repo              You
labctl hello 6  ── upload ──►  my-work/attendance.log   ◄── roster.py reads ──  class table
labctl submit 6 ── upload ──►  my-work/evidence/lab06_…
```

### One-time setup (10 minutes)

1. **Make sure students add you as a collaborator** (getting-started step 1.4). Each
   one sends you an invitation; `roster.py` accepts them all automatically.
2. **Create a GitHub token** so the script can read their repos:
   github.com ▸ your photo ▸ **Settings** ▸ **Developer settings** ▸ **Personal access
   tokens** ▸ **Tokens (classic)** ▸ **Generate new token (classic)**. Tick **`repo`**,
   set an expiry (e.g. 90 days), and copy the token.
   > The token is like a staff key: anyone holding it can read your repositories.
   > Never paste it into a file in the repository, a chat, or an email.
3. Open a codespace on your **`campusdb-lab-kit`** repository and run:
   ```bash
   python3 instructor/roster.py --setup
   ```
   Paste the token (it stays hidden). It's saved in your home folder, outside the repository.

### During and after a lab

```bash
python3 instructor/roster.py                # the class table, once
python3 instructor/roster.py --watch 120    # live during class: refreshes every 2 minutes
python3 instructor/roster.py --lab 6        # who has and hasn't submitted lab 6
```

| Column | Meaning |
|---|---|
| Here now* | Ran `labctl hello` in the last 3 hours |
| Last sign-in | Time of their latest `labctl hello` |
| Sessions | How many times they've signed in |
| Labs submitted | Lab numbers they've submitted with `labctl submit` |
| Lab 10 auto | Their auto-marked Part B score for the week 2 exam |
| Last upload | Last time anything reached their repository |

A spreadsheet copy is saved as `~/campusdb-roster.csv` (right-click it in the Explorer
▸ **Download**). Open any student's work directly at `github.com/<student>/campusdb-labs`.

**What it can't tell you:** whether someone is typing *right now*. "Here now" means
"signed in recently". For live checks during class, ask for a quick screenshot.

---

## 3. Updating the labs later

Students' repositories are copies taken on the day they created them, so later edits
to your template **don't reach them automatically**. After you change the template,
tell students to run:

```bash
labctl update
```

It replaces `labs/`, `scripts/`, `sql/` and `demo/` with your latest versions and never
touches `my-work/`.

> Students who created their repo **before** `labctl update` existed should run this
> one line instead (once):
> ```bash
> curl -fsSL https://codeload.github.com/Kofi-dba/campusdb-lab-kit/tar.gz/refs/heads/main | tar -xz --strip-components=1 campusdb-lab-kit-main/labs campusdb-lab-kit-main/scripts campusdb-lab-kit-main/sql && chmod +x scripts/*.sh
> ```

---

## 4. Suggested timetable (exam in two weeks covering weeks 1–2)

| Session | Lab | Notes |
|---|---|---|
| Week 1, lab 1 | Labs 1 + 2 | Lab 1 is short; start lab 2 if time allows |
| Week 1, lab 2 | Labs 3 + 4 | |
| End of week 1 | **Lab 5 mock exam** (60 min) | Mark it quickly; review the weakest questions in the next lecture |
| Week 2, lab 1 | Labs 6 + 7 | |
| Week 2, lab 2 | Labs 8 + 9 | Lab 9 homework = the syllabus backup plan |
| End of week 2 | **Lab 10 mock exam** (75 min) | Part B auto-marks; revise from the results before the real exam |

---

## 5. Running an online lab session (2 hours)

| Time | What happens |
|---|---|
| 0:00–0:10 | Everyone runs `labctl hello N` and `labctl start-lab N`. Keep `roster.py --watch` open in your own codespace to see who has arrived. |
| 0:10–0:25 | Screen-share the first know-how card and its commands in your own codespace. |
| 0:25–1:30 | Breakout rooms of 4–5 with a rotating "lab captain" who shares their screen. Rotate through rooms every 10–15 minutes. |
| 1:30–1:45 | One room presents its trickiest error and how they fixed it. |
| 1:45–2:00 | Everyone runs `labctl submit N`. Check `roster.py --lab N` and follow up with anyone missing. |

### The "aha" moment to make sure everyone sees

| Lab | Moment |
|---|---|
| 1 | `ls /var/lib/mysql` → Permission denied: the DBMS is the only gate |
| 2 | The wrong `AVG(score)` with a silent warning, vs `ERROR 1366` in the relational table; Terminal B waiting on the lock |
| 3 | `ERROR 1452` and `ERROR 1451`: referential integrity at work |
| 4 | `EXPLAIN`: `const` vs `ALL` |
| 6 | `DELETE FROM students_copy;` wipes everything; `--safe-updates` refuses it (`ERROR 1175`) |
| 7 | Five different constraint errors; `DROP TABLE students` refused (`ERROR 3730`) |
| 8 | The Consistency test: total money 1,400 until `ROLLBACK` |
| 9 | Abena missing after the restore (RPO), then found in the binary log |

---

## 6. Marking

- **Labs:** the evidence file shows the server state and the **SQL the student actually
  typed** (from their MySQL history), stamped with their GitHub username, codespace and
  time. Use it with their `my-work/labNN-notes.md` and the syllabus rubric.
- **Lab 5:** mark `my-work/lab05-answers.md` against the answer key. Cross-check Part B
  with the server facts in the evidence file.
- **Lab 10:** questions 13–19 are marked automatically (see "Part B auto-marking" in the
  evidence file, and the roster's *Lab 10 auto* column). Mark questions 1–12 and 20 by hand.

---

## 7. Troubleshooting

| Symptom | Fix |
|---|---|
| `Can't connect to local MySQL server through socket` | `labctl restart`, then `labctl doctor` |
| `labctl doctor` says "NOT linked to your own repository" | The student opened a codespace from your template page. They must create their own repo first (getting started 1.3), then a codespace from it |
| A student doesn't appear in the roster | They haven't added `Kofi-dba` as a collaborator, or named their repo without "campusdb" |
| Roster says the token was refused (401) | It expired: create a new one and run `--setup` again |
| Lab 9: `mysql_config_editor` not found | Use `-u root -p` instead of `--login-path=lab` in every command |
| Lab 9: `log_bin` is OFF | Skip Part 6; explain the binary log conceptually |
| `Access denied for user 'root'` | Root password was changed: use the new one, then `labctl rootpw` |
