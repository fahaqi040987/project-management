# Design Spec: Optimize VPS Resource Usage

## Objective
Reduce the memory footprint of the project from the current ~2GB+ limit down to comfortable usage within a 2GB RAM / 2 CPU VPS environment, without modifying the underlying application code or removing existing features.

## Architecture & Configuration
To achieve this, we will transition from relying purely on defaults to a more tuned containerized environment.

### Components Change
1. **Database:** Replace `mysql:8.0` with `mariadb:11` to achieve an immediate reduction in idle and operational RAM.
2. **Queue Worker:** Remove the separate `queue` Docker service. Instead, run `supervisord` inside the main `app` container to manage both `php-fpm` and `php artisan queue:work` within a single container boundary, reducing the OS/Docker overhead of running a duplicate PHP environment.
3. **Web Server:** Unchanged (Nginx Alpine).
4. **Cloudflared & phpMyAdmin:** Unchanged.

### Tuning Parameters
- **PHP-FPM (`php/local.ini` & pool configuration):**
  - Limit `memory_limit` to `128M`.
  - Adjust FPM `pm.max_children` to a reasonable number (e.g., `5`) so FPM does not spawn too many RAM-heavy processes.
- **MariaDB (`docker/mysql/my.cnf`):**
  - Limit `innodb_buffer_pool_size` to `128M`.
  - Limit `max_connections` to `100`.
- **VPS OS Host:**
  - Create a utility script to establish a 2GB Swap file on the host VPS. This will act as a safety net to prevent Out-Of-Memory (OOM) killer terminations during brief peak usage.

## Data Migration Flow
Since we are switching the database engine, the existing volume `laravel-data` holding MySQL 8.0 internal files cannot be reused directly by MariaDB.

1. **Backup:** A shell script `backup-db.sh` will dump the current database to a `database/backups/dump.sql` file on the host.
2. **Tear down & Clean:** The `db` service is stopped and the `laravel-data` volume is removed.
3. **Update Definition:** The `docker-compose.yml` is updated to point to `mariadb:11` and include the tuned `my.cnf` configuration.
4. **Restore:** The stack is restarted. A restore script `restore-db.sh` will inject the SQL dump into the new MariaDB container.

## Implementation Steps
1. Create `backup-db.sh` and `restore-db.sh` scripts.
2. Create MariaDB custom configuration file at `docker/mysql/my.cnf`.
3. Create `docker/supervisord.conf` for the `app` container.
4. Modify `Dockerfile` to install supervisor.
5. Modify `docker/entrypoint.sh` to start `supervisord` instead of directly executing `php-fpm`.
6. Update `docker-compose.yml` to remove the `queue` service and switch `db` to MariaDB.
7. Update `php/local.ini` with tuning settings.
8. Create a `setup-swap.sh` script to configure swap on the host VPS.

## Error Handling & Fallbacks
- The database backup script must confirm the existence and non-zero size of the SQL dump before allowing the user to delete the Docker volume.
- If Supervisor fails to start either FPM or the Queue, the container will exit, triggering Docker's restart policy. logs will be accessible via standard Docker stdout.
