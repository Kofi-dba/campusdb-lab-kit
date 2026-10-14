mkdir -p .devcontainer my-work && touch my-work/.gitkeep
cat > .devcontainer/Dockerfile <<'CAMPUSDB_EOF'
# CampusDB lab environment
# Ubuntu 24.04 + a real MySQL 8.0 server installed the normal way, so every
# command in the syllabus (local accounts, sockets, my.cnf, mysql_secure_installation,
# validate_password, mysqldump) behaves exactly as it would on a real server.
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        mysql-server-8.0 \
        mysql-client-8.0 \
        python3 \
        python3-pymysql \
        openssl \
        gzip \
        less \
        nano \
 && rm -rf /var/lib/apt/lists/*

# A friendly prompt reminder: students always know they are in the lab box.
RUN echo 'echo "CampusDB lab ready. Type: labctl help"' >> /etc/bash.bashrc
CAMPUSDB_EOF
cat > .devcontainer/devcontainer.json <<'CAMPUSDB_EOF'
{
  "name": "CampusDB MySQL Lab",
  "build": { "dockerfile": "Dockerfile" },

  // 2 cores is plenty for MySQL with a few thousand rows and doubles the free hours.
  "hostRequirements": { "cpus": 2 },

  // Runs once, when the codespace is first created: sets the lab root password.
  "postCreateCommand": "bash .devcontainer/post-create.sh",

  // Runs every time the codespace starts or wakes up: starts MySQL.
  "postStartCommand": "bash .devcontainer/post-start.sh",

  "remoteUser": "vscode",

  "customizations": {
    "vscode": {
      "extensions": [
        "mtxr.sqltools",
        "mtxr.sqltools-driver-mysql"
      ],
      "settings": {
        "terminal.integrated.defaultProfile.linux": "bash",
        "sqltools.connections": [
          {
            "name": "CampusDB (root)",
            "driver": "MySQL",
            "server": "127.0.0.1",
            "port": 3306,
            "username": "root",
            "askForPassword": true,
            "database": "mysql"
          }
        ]
      }
    },
    "codespaces": {
      "openFiles": ["labs/00-getting-started.md"]
    }
  }
}
CAMPUSDB_EOF
cat > .devcontainer/post-create.sh <<'CAMPUSDB_EOF'
#!/usr/bin/env bash
# Runs ONCE when the codespace is created.
set -euo pipefail

LAB_ROOT_PW='ChangeMe!2026'
CONF_DIR="$HOME/.campusdb"

echo ">> Starting MySQL for first-time setup..."
bash "$(dirname "$0")/post-start.sh"

# Ubuntu's MySQL lets the Linux root user in through the socket with no password
# (auth_socket). The syllabus expects `mysql -u root -p` with a password, so switch
# root to normal password login. Only do it if it hasn't been done yet.
if sudo mysql -e "SELECT 1" >/dev/null 2>&1; then
  sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '${LAB_ROOT_PW}';"
  echo ">> Root password set to the lab default."
fi

# Private credentials file used ONLY by the labctl helper (chmod 600 = only you can read it).
# Students: this is itself a lesson - real servers keep admin secrets in protected
# files or a vault, never inside scripts.
mkdir -p "$CONF_DIR"
cat > "$CONF_DIR/root.cnf" <<EOF
[client]
user=root
password=${LAB_ROOT_PW}
EOF
chmod 600 "$CONF_DIR/root.cnf"

# Put the helper on the PATH.
sudo ln -sf "$PWD/scripts/labctl.sh" /usr/local/bin/labctl
chmod +x scripts/*.sh demo/*.py 2>/dev/null || true

echo ">> CampusDB lab environment is ready."
CAMPUSDB_EOF
cat > .devcontainer/post-start.sh <<'CAMPUSDB_EOF'
#!/usr/bin/env bash
# Runs EVERY time the codespace starts or wakes from sleep (and once from post-create).
# Codespaces has no systemd, so MySQL does not start by itself after a stop.

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
CAMPUSDB_EOF
cat > .gitignore <<'CAMPUSDB_EOF'
my-work/restore.sql
my-work/restore.sql.gz
*.pyc
__pycache__/
CAMPUSDB_EOF
chmod +x .devcontainer/*.sh scripts/*.sh demo/*.py
ls -la .devcontainer
