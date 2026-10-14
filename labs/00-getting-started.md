# Getting started: your own MySQL server in the browser

You do **not** install anything. Each of you gets a private Linux computer in the
cloud (a *codespace*) with MySQL 8.0 already installed. Only you can see it.

> **Analogy:** the university has built every student their own small library
> branch. You get the keys to *your* branch. If you knock the shelves over, nobody
> else's branch is affected, and the caretaker (`labctl`) can rebuild yours in seconds.

## 1. One-time setup (10 minutes, do this before Lab 1)

1. Create a free GitHub account at <https://github.com> if you don't have one.
   Use a username you'd be happy for an employer to see.
2. **Recommended:** apply for the free GitHub Student Developer Pack with your
   university email (<https://education.github.com/pack>). Verified students get
   more free codespace hours each month.
3. Open the link your lecturer posted for this course and accept the assignment.
   GitHub creates *your own copy* of the lab repository.
4. On your repository page click **Code ▸ Codespaces ▸ Create codespace on main**.
5. Wait 2–4 minutes the very first time. When you see a terminal at the bottom
   that says `CampusDB lab ready`, you're in.

## 2. Check that everything works

In the terminal, type:

```bash
labctl doctor
```

You should see three green `[ok]` lines. Then log in to MySQL yourself:

```bash
mysql -u root -p
```

Password: **`ChangeMe!2026`** (you'll change this in week 4). You'll see the
`mysql>` prompt. Type `exit` to leave.

## 3. Your screen, explained

| Part of the screen | What it is | Library analogy |
|---|---|---|
| Terminal (bottom) | Where you type commands to Linux and MySQL | The enquiry desk |
| Explorer (left) | Files in your repository: lab guides, your work | The filing cabinet |
| `labs/` folder | The lab instructions | The lesson handouts |
| `my-work/` folder | Save your SQL scripts and evidence here | Your personal locker |

**Two prompts, two languages.** When the prompt ends in `$` you are talking to
Linux. When it says `mysql>` you are talking to MySQL. Linux commands (like
`mysqldump`) don't work at `mysql>`, and SQL doesn't work at `$`. If a command
fails strangely, check which prompt you're at first.

## 4. Habits that save marks

- **End every SQL statement with `;`**. If MySQL shows `->` it is waiting for the
  rest of your statement. Type `;` and press Enter.
- **Save your SQL in a file** in `my-work/` (e.g. `my-work/lab2.sql`) and run it with
  `SOURCE my-work/lab2.sql;` from the `mysql>` prompt. Typing everything by hand
  live is how typos eat your lab time.
- **Codespaces go to sleep after 30 minutes idle.** Your data is kept. When you
  reopen it, MySQL restarts automatically.
- **Commit and push `my-work/`** at the end of every lab (Source Control icon ▸
  write a message ▸ Commit ▸ Sync). That's your off-site copy (remember 3-2-1).
- **Stop your codespace when you're done** (Codespaces menu ▸ Stop) so you don't
  burn free hours.

## 5. If something goes wrong

| Problem | Fix |
|---|---|
| `Can't connect to local MySQL server through socket` | `sudo service mysql start` then `labctl doctor` |
| You forgot where you were / broke the database | `labctl start-week N` resets you to the start of week N |
| Missed a lab | `labctl start-week N` for the week you're joining |
| `Access denied for user 'root'` after week 4 | You changed root's password: use the new one, then `labctl rootpw` |
| The codespace won't open | Go to <https://github.com/codespaces>, delete it, create a new one, then `labctl start-week N` |

## 6. How you submit labs

At the end of each lab run `labctl check N` (N = lab number). It writes
`my-work/evidence/labN_<your-username>.txt`, stamped with your GitHub name and
time. Upload that file plus your written answers and screenshots to the course page.
