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
