# Optimize VPS Resource Usage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce memory footprint to run comfortably in a 2GB RAM VPS by migrating to MariaDB, configuring Supervisor, tuning PHP-FPM, and adding Swap.

**Architecture:** Replace MySQL 8.0 with MariaDB 11, merge queue worker into the app container via Supervisor, tune FPM/DB memory limits, and implement a host Swap script.

**Tech Stack:** Docker, MariaDB, Supervisor, Bash.

---

### Task 1: Create Database Migration Scripts

**Files:**
- Create: `database/backups/backup-db.sh`
- Create: `database/backups/restore-db.sh`

- [ ] **Step 1: Create the backup script**

```bash
#!/bin/bash
# database/backups/backup-db.sh
set -e

echo "Backing up database from mysql:8.0 container..."
mkdir -p "$(dirname "$0")"

# Execute dump inside the currently running container
docker exec laravel_db mysqldump -u root -p"${DB_PASSWORD}" nexabtn_management > "$(dirname "$0")/dump.sql"

if [ -s "$(dirname "$0")/dump.sql" ]; then
    echo "Backup successful! Saved to database/backups/dump.sql"
else
    echo "Backup failed or file is empty!"
    exit 1
fi
```

- [ ] **Step 2: Create the restore script**

```bash
#!/bin/bash
# database/backups/restore-db.sh
set -e

echo "Restoring database to mariadb:11 container..."

if [ ! -f "$(dirname "$0")/dump.sql" ]; then
    echo "Error: dump.sql not found!"
    exit 1
fi

cat "$(dirname "$0")/dump.sql" | docker exec -i laravel_db mysql -u root -p"${DB_PASSWORD}" nexabtn_management

echo "Restore successful!"
```

- [ ] **Step 3: Make scripts executable**

Run: `chmod +x database/backups/backup-db.sh database/backups/restore-db.sh`
Expected: Execution bit set.

- [ ] **Step 4: Commit**

```bash
git add database/backups/backup-db.sh database/backups/restore-db.sh
git commit -m "feat: add database migration scripts"
```

### Task 2: Configure MariaDB Tuning

**Files:**
- Create: `docker/mysql/my.cnf`

- [ ] **Step 1: Create the custom my.cnf**

```ini
[mysqld]
# Memory optimization for 2GB RAM VPS
innodb_buffer_pool_size=128M
max_connections=100
key_buffer_size=16M
thread_cache_size=4
host_cache_size=0
skip-name-resolve
```

- [ ] **Step 2: Commit**

```bash
git add docker/mysql/my.cnf
git commit -m "chore: add mariadb tuned configuration"
```

### Task 3: Configure Supervisor for App Container

**Files:**
- Create: `docker/supervisord.conf`
- Modify: `Dockerfile`
- Modify: `docker/entrypoint.sh`

- [ ] **Step 1: Create supervisord.conf**

```ini
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisord.log
pidfile=/var/run/supervisord.pid

[program:php-fpm]
command=php-fpm
autostart=true
autorestart=true
priority=5
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:laravel-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/artisan queue:work --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=www-data
numprocs=1
redirect_stderr=true
stdout_logfile=/var/www/storage/logs/worker.log
stopwaitsecs=3600
```

- [ ] **Step 2: Modify Dockerfile to install supervisor**

Update `Dockerfile` to add `supervisor` to the apt-get install list and copy the configuration.

```dockerfile
# Update lines 4-13 to include supervisor
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libicu-dev \
    libzip-dev \
    zip \
    unzip \
    git \
    curl \
    supervisor

# Before the WORKDIR instruction, copy supervisord.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Change CMD from php-fpm to supervisord
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
```

- [ ] **Step 3: Modify entrypoint.sh to start supervisor**

Update the last line of `docker/entrypoint.sh`:

```bash
# Change:
# exec php-fpm
# To:
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
```

- [ ] **Step 4: Commit**

```bash
git add docker/supervisord.conf Dockerfile docker/entrypoint.sh
git commit -m "feat: configure supervisor for fpm and queue worker"
```

### Task 4: Update PHP Configuration

**Files:**
- Modify: `php/local.ini`

- [ ] **Step 1: Update PHP memory limit**

Append to `php/local.ini`:

```ini
memory_limit=128M
pm.max_children=5
```

- [ ] **Step 2: Commit**

```bash
git add php/local.ini
git commit -m "chore: tune php-fpm memory limits"
```

### Task 5: Update Docker Compose

**Files:**
- Modify: `docker-compose.yml`

- [ ] **Step 1: Update docker-compose.yml**

Changes:
1. Remove the `queue` service entirely.
2. Change `db` service image to `mariadb:11`
3. Add volume mount to `db` service: `- ./docker/mysql/my.cnf:/etc/mysql/conf.d/my.cnf`
4. Update healthcheck for `db` to work with MariaDB (replace `mysqladmin` with standard ping if necessary, but `mysqladmin` works for MariaDB too).
5. Remove `depends_on` from `queue` to `app` and `db` since `queue` is removed.

*Note: The exact diff will be applied during execution.*

- [ ] **Step 2: Commit**

```bash
git add docker-compose.yml
git commit -m "chore: switch to mariadb and remove separate queue service"
```

### Task 6: Create Swap Setup Script

**Files:**
- Create: `setup-swap.sh`

- [ ] **Step 1: Create setup-swap.sh**

```bash
#!/bin/bash
# setup-swap.sh
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

SWAP_SIZE="2G"
SWAP_FILE="/swapfile"

if grep -q "swap" /etc/fstab; then
    echo "Swap already exists."
    exit 0
fi

echo "Creating ${SWAP_SIZE} swap file..."
fallocate -l ${SWAP_SIZE} ${SWAP_FILE}
chmod 600 ${SWAP_FILE}
mkswap ${SWAP_FILE}
swapon ${SWAP_FILE}

echo "${SWAP_FILE} none swap sw 0 0" >> /etc/fstab

echo "Swap setup complete!"
free -h
```

- [ ] **Step 2: Make script executable**

Run: `chmod +x setup-swap.sh`
Expected: Execution bit set.

- [ ] **Step 3: Commit**

```bash
git add setup-swap.sh
git commit -m "feat: add swap setup utility script"
```
