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
