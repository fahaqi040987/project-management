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
