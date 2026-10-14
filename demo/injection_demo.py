#!/usr/bin/env python3
"""
SQL injection demo for Lab 4 - a tiny "student lookup portal".

It searches campusdb.students by last name two ways:
  1. UNSAFE - glues your input into the SQL text (string concatenation)
  2. SAFE   - a parameterised query: SQL shape sent first, your input sent
              separately and treated ONLY as a value

It connects as 'portal_app'@'localhost', the least-privilege account you
create in Lab 4 (SELECT on campusdb.students only).

Run:   python3 demo/injection_demo.py
Try these inputs:
   Mensah
   ' OR '1'='1
   ' UNION SELECT user, host, plugin, authentication_string FROM mysql.user #
   ' UNION SELECT payment_id, student_id, amount_ghs, paid_on FROM fees #
   '; DROP TABLE students; #

Library analogy: the unsafe version is the careless librarian who reads the
whole request slip as orders. The safe version only ever treats what is
written in the blank as a name to look up.
"""
import getpass
import sys

try:
    import pymysql
except ImportError:
    sys.exit("pymysql is missing. Run: sudo apt-get install -y python3-pymysql")

SOCKET = "/var/run/mysqld/mysqld.sock"


def connect(password):
    return pymysql.connect(
        unix_socket=SOCKET,       # local socket counts as a secure transport
        user="portal_app",
        password=password,
        database="campusdb",
    )


def unsafe_lookup(conn, last_name):
    sql = ("SELECT student_id, first_name, last_name, email FROM students "
           "WHERE last_name = '" + last_name + "'")
    print(f"\n  SQL actually sent to MySQL:\n    {sql}")
    with conn.cursor() as cur:
        cur.execute(sql)
        return cur.fetchall()


def safe_lookup(conn, last_name):
    sql = "SELECT student_id, first_name, last_name, email FROM students WHERE last_name = %s"
    print(f"\n  SQL shape sent to MySQL:\n    {sql}\n  Value sent separately: {last_name!r}")
    with conn.cursor() as cur:
        cur.execute(sql, (last_name,))
        return cur.fetchall()


def show(label, fn, conn, value):
    print(f"\n--- {label} ---")
    try:
        rows = fn(conn, value)
        print(f"  Rows returned: {len(rows)}")
        for r in rows:
            print("   ", r)
    except pymysql.MySQLError as e:
        print(f"  MySQL refused it: {e.args[0]} {e.args[1]}")


def main():
    pw = getpass.getpass("Password for portal_app: ")
    try:
        conn = connect(pw)
    except pymysql.MySQLError as e:
        sys.exit(f"Could not connect as portal_app: {e}\n"
                 "Did you create the account in Lab 4, step 1?")

    print("Type a last name to search (or 'quit').")
    while True:
        try:
            value = input("\nLast name> ")
        except EOFError:
            break
        if value.strip().lower() in ("quit", "exit"):
            break
        show("UNSAFE (string concatenation)", unsafe_lookup, conn, value)
        show("SAFE (parameterised query)", safe_lookup, conn, value)
    conn.close()


if __name__ == "__main__":
    main()
