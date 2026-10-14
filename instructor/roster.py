#!/usr/bin/env python3
"""
CampusDB class roster - see who has signed in and what they have submitted.

How it works (the "attendance book" analogy):
  * Each student adds you as a collaborator on their private campusdb-labs repo.
  * `labctl hello N` writes a line in my-work/attendance.log and uploads it.
  * `labctl submit N` writes a 'submit' line and uploads the evidence file.
  * This script reads every student's attendance book through the GitHub API
    and prints one table for the whole class.

Usage (run it in a codespace or any computer with Python 3):
  python3 instructor/roster.py --setup        # once: paste a GitHub token
  python3 instructor/roster.py                # print the class table
  python3 instructor/roster.py --watch 120    # refresh every 2 minutes during a lab
  python3 instructor/roster.py --lab 5        # who has / hasn't submitted lab 5

Your token and the CSV copy (~/campusdb-roster.csv) are kept in your HOME folder,
never inside the repository, so student names are never published.
"""
import argparse
import base64
import csv
import datetime as dt
import getpass
import json
import os
import sys
import time
import urllib.error
import urllib.request

API = "https://api.github.com"
TOKEN_FILE = os.path.expanduser("~/.campusdb/gh_token")
CSV_FILE = os.path.expanduser("~/campusdb-roster.csv")
REPO_HINT = "campusdb"          # only repos whose name contains this are counted


# --------------------------------------------------------------------- GitHub
def token():
    t = os.environ.get("ROSTER_TOKEN")
    if not t and os.path.exists(TOKEN_FILE):
        t = open(TOKEN_FILE).read().strip()
    if not t:
        sys.exit("No token yet. Run:  python3 instructor/roster.py --setup")
    return t


def gh(path, method="GET", tok=None):
    req = urllib.request.Request(API + path, method=method)
    req.add_header("Authorization", "Bearer " + (tok or token()))
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            body = r.read()
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        if e.code == 401:
            sys.exit("GitHub refused the token (401). Run --setup again with a new token.")
        raise


def gh_all(path):
    items, page = [], 1
    sep = "&" if "?" in path else "?"
    while True:
        batch = gh(f"{path}{sep}per_page=100&page={page}") or []
        items += batch
        if len(batch) < 100:
            return items
        page += 1


def read_file(full_name, path):
    data = gh(f"/repos/{full_name}/contents/{path}")
    if not data or "content" not in data:
        return None
    return base64.b64decode(data["content"]).decode("utf-8", "replace")


# ---------------------------------------------------------------------- steps
def setup():
    print(__doc__.split("Usage")[0])
    print("Create a token: github.com > your photo > Settings > Developer settings >")
    print("Personal access tokens > Tokens (classic) > Generate new token (classic).")
    print("Tick the 'repo' box, set an expiry (e.g. 90 days), then copy the token.\n")
    t = getpass.getpass("Paste the token here (it stays hidden): ").strip()
    me = gh("/user", tok=t)
    os.makedirs(os.path.dirname(TOKEN_FILE), exist_ok=True)
    with open(TOKEN_FILE, "w") as f:
        f.write(t)
    os.chmod(TOKEN_FILE, 0o600)
    print(f"\nSaved. Logged in to GitHub as: {me['login']}")


def accept_invitations():
    accepted = []
    for inv in gh_all("/user/repository_invitations"):
        name = inv["repository"]["full_name"]
        if REPO_HINT in name.lower():
            gh(f"/user/repository_invitations/{inv['id']}", method="PATCH")
            accepted.append(name)
    return accepted


def parse_attendance(text):
    hellos, submits, last_hello = 0, set(), ""
    for line in (text or "").splitlines():
        parts = line.split()
        if "hello" in parts:
            hellos += 1
            last_hello = " ".join(parts[:3])          # "2026-10-14 09:02 UTC"
        if "submit" in parts:
            for p in parts:
                if p.startswith("lab="):
                    submits.add(int(p[4:]))
    return hellos, submits, last_hello


def lab10_score(full_name, owner):
    text = read_file(full_name, f"my-work/evidence/lab10_{owner}.txt") or ""
    for line in text.splitlines():
        if "Auto-marked practical score" in line:
            return line.split(":", 1)[1].strip()
    return ""


def signed_in_recently(stamp, hours=3):
    try:
        t = dt.datetime.strptime(stamp, "%Y-%m-%d %H:%M UTC").replace(tzinfo=dt.timezone.utc)
    except ValueError:
        return False
    return dt.datetime.now(dt.timezone.utc) - t < dt.timedelta(hours=hours)


def collect():
    me = gh("/user")["login"]
    new = accept_invitations()
    repos = [r for r in gh_all("/user/repos?affiliation=collaborator")
             if REPO_HINT in r["name"].lower() and r["owner"]["login"] != me]
    rows = []
    for r in sorted(repos, key=lambda x: x["owner"]["login"].lower()):
        owner, full = r["owner"]["login"], r["full_name"]
        hellos, submits, last_hello = parse_attendance(read_file(full, "my-work/attendance.log"))
        rows.append({
            "student": owner,
            "repo": full,
            "now": "yes" if signed_in_recently(last_hello) else "",
            "last_sign_in": last_hello or "never",
            "sessions": hellos,
            "labs_submitted": ",".join(str(n) for n in sorted(submits)) or "-",
            "lab10_auto": lab10_score(full, owner) if 10 in submits else "",
            "last_push": (r.get("pushed_at") or "").replace("T", " ").replace("Z", " UTC"),
        })
    return new, rows


# --------------------------------------------------------------------- output
def show(new, rows, lab=None):
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    print(f"\nCampusDB class roster - {stamp}")
    if new:
        print(f"Accepted {len(new)} new invitation(s): {', '.join(new)}")
    if not rows:
        print("\nNo student repositories yet. Students must add you as a collaborator.")
        return
    cols = [("student", "Student"), ("now", "Here now*"), ("last_sign_in", "Last sign-in"),
            ("sessions", "Sessions"), ("labs_submitted", "Labs submitted"),
            ("lab10_auto", "Lab 10 auto"), ("last_push", "Last upload")]
    width = {k: max(len(h), *(len(str(r[k])) for r in rows)) for k, h in cols}
    print("\n" + "  ".join(h.ljust(width[k]) for k, h in cols))
    print("  ".join("-" * width[k] for k, _ in cols))
    for r in rows:
        print("  ".join(str(r[k]).ljust(width[k]) for k, _ in cols))
    here = sum(1 for r in rows if r["now"])
    print(f"\n{len(rows)} students | {here} signed in during the last 3 hours")
    print("* 'Here now' = ran `labctl hello` in the last 3 hours.")
    if lab:
        done = [r["student"] for r in rows if str(lab) in r["labs_submitted"].split(",")]
        todo = [r["student"] for r in rows if r["student"] not in done]
        print(f"\nLab {lab}: {len(done)} submitted, {len(todo)} not yet")
        if todo:
            print("  Not yet: " + ", ".join(todo))
    with open(CSV_FILE, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print(f"\nSpreadsheet copy saved to {CSV_FILE}")


def main():
    ap = argparse.ArgumentParser(description="CampusDB class roster")
    ap.add_argument("--setup", action="store_true", help="save your GitHub token")
    ap.add_argument("--watch", type=int, metavar="SECONDS", help="refresh every N seconds")
    ap.add_argument("--lab", type=int, help="list who has / hasn't submitted this lab")
    a = ap.parse_args()
    if a.setup:
        return setup()
    while True:
        new, rows = collect()
        if a.watch:
            os.system("clear")
        show(new, rows, a.lab)
        if not a.watch:
            break
        print(f"\nRefreshing every {max(a.watch, 60)} s. Press Ctrl + C to stop.")
        time.sleep(max(a.watch, 60))


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print()
