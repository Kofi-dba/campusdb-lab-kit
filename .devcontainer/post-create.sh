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
