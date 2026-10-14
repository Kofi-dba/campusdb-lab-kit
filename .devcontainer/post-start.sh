#!/usr/bin/env bash
# Runs EVERY time the codespace starts or wakes from sleep (and once from post-create).
# Codespaces has no systemd, so MySQL does not start by itself after a stop.

# Whatever happens below, make sure ordinary users (you, labctl) can reach the
# MySQL socket "door". Without this you get: ERROR 2002 ... mysqld.sock' (13)
trap 'sudo chmod 755 /var/run/mysqld 2>/dev/null || true' EXIT

up() { sudo mysqladmin ping >/dev/null 2>&1; }   # exit 0 when the server answers

wait_up() { for i in $(seq 1 30); do up && return 0; sleep 1; done; return 1; }

up && { echo ">> MySQL is already running."; exit 0; }

# Normal way: the init script that ships with Ubuntu's mysql-server package.
sudo service mysql start >/dev/null 2>&1
wait_up && { echo ">> MySQL is running."; exit 0; }

# Fallback: start mysqld directly (in case the init script is missing or fails).
sudo mkdir -p /var/run/mysqld && sudo chown mysql:mysql /var/run/mysqld
sudo -u mysql mysqld --daemonize --pid-file=/var/run/mysqld/mysqld.pid >/dev/null 2>&1
wait_up && { echo ">> MySQL is running (started directly)."; exit 0; }

echo "!! MySQL did not start. Show your lecturer:  sudo tail -n 30 /var/log/mysql/error.log"
exit 1
