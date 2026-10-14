# Getting started: your own MySQL server in the browser

You do **not** install anything. Each of you gets a private Linux computer in the
cloud (a *codespace*) with MySQL 8.0 already installed. Only you can use it.

> **Analogy:** the university has built every student their own small library
> branch. You get the keys to *your* branch. If you knock the shelves over, nobody
> else's branch is affected, and the caretaker (`labctl`) can rebuild yours in seconds.

---

## 1. One-time setup (15 minutes, before Lab 1)

1. **Create a free GitHub account** at <https://github.com>. Pick a professional
   username: employers may see it.
2. **Recommended:** apply for the free **GitHub Student Developer Pack** with your
   university email at <https://education.github.com/pack>. It gives you more free
   codespace hours every month.
3. **Make your own copy of the labs.** Open your lecturer's link:
   **<https://github.com/Kofi-dba/campusdb-lab-kit>**, then click the green
   **Use this template** ▸ **Create a new repository**.
   - Repository name: **`campusdb-labs`**
   - Choose **Private**
   - Click **Create repository**
4. **Let your lecturer see your work.** On *your* new repository: **Settings** ▸
   **Collaborators** ▸ **Add people** ▸ type **`Kofi-dba`** ▸ **Add**.
   (This is how your attendance and submissions reach your lecturer. Classmates can't see it.)
5. **Build your lab computer.** On your repository page click the green **Code** ▸
   **Codespaces** tab ▸ **Create codespace on main**. The first build takes 3–5
   minutes. When the terminal at the bottom says `CampusDB lab ready`, you're in.

> ⚠️ Always open your codespace **from your own repository** (`your-name/campusdb-labs`),
> never from your lecturer's page. Otherwise your work can't be saved to GitHub.

## 2. Check that everything works

```bash
labctl doctor
```

You want green `[ok]` lines, including **"Linked to GitHub repo: your-name/campusdb-labs"**.
Then log in to MySQL yourself:

```bash
mysql -u root -p
```

Password: **`ChangeMe!2026`** (nothing appears as you type). At the `mysql>` prompt,
type `exit` to leave.

## 3. The routine for EVERY lab

| When | Command | What it does |
|---|---|---|
| Start of the lab | `labctl hello N` | Signs the attendance book (your lecturer sees you've arrived) |
| Start of the lab | `labctl start-lab N` | Puts your server in the right state for lab N |
| During the lab | follow `labs/labNN-….md` | |
| End of the lab | `labctl submit N` | Writes your evidence file and saves `my-work/` to GitHub |

(N is the lab number, 1 to 10.)

## 4. Your screen, explained

| Part of the screen | What it is | Library analogy |
|---|---|---|
| Terminal (bottom) | Where you type commands | The enquiry desk |
| Explorer (left) | Your files: lab sheets, your work | The filing cabinet |
| `labs/` folder | The lab sheets | Lesson handouts |
| `my-work/` folder | Your notes, scripts, answers and evidence | Your personal locker |

**Easiest way to read a lab sheet:** open it on GitHub in a second browser tab (it's
nicely formatted there), and keep the codespace beside it. Inside the codespace you can
also open the file and press **Ctrl + Shift + V** for a formatted preview.

**Two prompts, two languages.** `$` = you're talking to **Linux**. `mysql>` = you're
talking to **MySQL**. If a command fails strangely, check which prompt you're at.

## 5. Habits that save marks

- **End every SQL statement with `;`**. If MySQL shows `->`, it's waiting for the rest.
- **Type `exit` before `labctl submit`**, so your SQL history is saved into the evidence.
- **Save longer SQL in a file** in `my-work/` and run it with `SOURCE my-work/file.sql;`.
- **Codespaces sleep after 30 minutes idle.** Your work is kept; MySQL restarts when you return.
- **Stop your codespace when you're done:** <https://github.com/codespaces> ▸ **⋯** ▸
  **Stop codespace**. It saves your free hours.

## 6. If something goes wrong

| Problem | Fix |
|---|---|
| `Can't connect to local MySQL server through socket` | `labctl restart`, then `labctl doctor` |
| You broke the database or missed a lab | `labctl start-lab N` resets you to the start of lab N |
| `labctl doctor` says "NOT linked to your own repository" | You opened the codespace from the lecturer's page. Redo step 1.3 and 1.5 |
| `labctl submit` says it could not upload | Run it again; if it still fails, download your `my-work/` files and upload them to the course page |
| Your lecturer says the lab sheets were updated | `labctl update` |
| The codespace won't open | <https://github.com/codespaces> ▸ delete it ▸ create a new one from your repository, then `labctl start-lab N` |
