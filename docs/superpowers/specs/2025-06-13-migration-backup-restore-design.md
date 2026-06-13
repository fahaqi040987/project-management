# Migration Backup/Restore Tools Design

**Date:** 2025-06-13  
**Status:** Approved  
**Type:** Infrastructure Tool

---

## Overview

Dua bash script untuk melakukan full migration aplikasi DewaKoding Project Management dari server lama ke server baru:

- `backup-migration.sh` — Dump seluruh project ke compressed archive di server lama
- `restore-migration.sh` — Extract dan setup di server baru

**Use Case:** One-time server migration dengan manual execution

---

## Problem Statement

Project saat ini memiliki basic backup scripts (`database/backups/backup-db.sh`) namun:
- Hanya backup database, tidak include storage files
- Tidak include configuration (.env)
- Tidak ada restore script yang comprehensive
- Tidak portable untuk transfer antar server

Untuk memindahkan seluruh aplikasi ke server baru dibutuhkan tool yang bisa backup dan restore semua data dan config.

---

## Proposed Solution

### Components

**Backup Script:** `/scripts/backup-migration.sh`
- Dump MySQL database
- Collect Laravel storage files
- Copy .env configuration
- Compress semua ke single archive

**Restore Script:** `/scripts/restore-migration.sh`
- Extract backup archive
- Import database
- Restore storage files
- Setup .env di server baru

### Backup Archive Structure

```
project-management-YYYY-MM-DD-HHMMSS.tar.gz
├── database/
│   └── dump.sql                 # Full MySQL dump
├── storage/                      # Laravel storage directory
│   ├── app/                      # User uploads (jika ada)
│   ├── framework/               # Cache, sessions, views
│   └── logs/                     # Application logs
├── env-config                    # .env file (sensitive keys masked)
├── metadata.json                 # Backup info & checksum
└── README.txt                    # Restore instructions
```

### metadata.json Format

```json
{
  "backup_date": "2025-06-13T10:30:00+07:00",
  "version": "1.0.0",
  "database_name": "nexabtn_management",
  "database_size_bytes": 12345678,
  "storage_size_bytes": 9876543,
  "total_size_bytes": 22222221,
  "checksum": "sha256:abc123...",
  "hostname": "server-a.example.com",
  "app_url": "https://nexabtn.my.id"
}
```

---

## Data Flow

### Backup Process (Server A)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Check Prerequisites                                      │
│    - Docker running                                         │
│    - mysqldump available                                   │
│    - Disk space sufficient                                 │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Prepare Temporary Directory                             │
│    mkdir -p /tmp/migration-backup                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Dump Database                                            │
│    docker exec laravel_db mysqldump \                      │
│      -u root -p"${DB_PASSWORD}" \                          │
│      ${DB_DATABASE} > /tmp/migration-backup/dump.sql      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Copy Storage Files                                       │
│    cp -r storage/app /tmp/migration-backup/               │
│    cp -r storage/framework /tmp/migration-backup/         │
│    cp -r storage/logs /tmp/migration-backup/              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Copy Environment Config                                 │
│    cp .env /tmp/migration-backup/env-config                │
│    # Mask sensitive keys: APP_KEY, DB_PASSWORD, etc.      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. Generate Metadata                                       │
│    # Create metadata.json with checksums and info          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. Create README                                            │
│    # Instructions for restore                              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 8. Compress All                                             │
│    tar -czf project-management-[timestamp].tar.gz \        │
│      -C /tmp/migration-backup .                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 9. Cleanup & Report                                         │
│    rm -rf /tmp/migration-backup                            │
│    echo "Backup: /backups/xxx.tar.gz (XX MB)"              │
└─────────────────────────────────────────────────────────────┘
```

### Transfer Process

```bash
# Via SCP dari lokal atau server A → server B
scp /backups/project-management-2025-06-13.tar.gz user@server-b:/tmp/
```

### Restore Process (Server B)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Check Prerequisites                                      │
│    - Docker installed                                      │
│    - Docker Compose installed                              │
│    - Project cloned                                        │
│    - .env exists or will be created                        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Validate Backup                                          │
│    - Check file integrity (checksum)                       │
│    - Verify metadata.json                                  │
│    - Check version compatibility                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Extract Archive                                          │
│    tar -xzf /tmp/project-management-xxx.tar.gz \           │
│      -C /tmp/migration-restore                              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Setup Environment (Interactive)                         │
│    # Load from backup, prompt for sensitive keys:          │
│    - APP_KEY (generate new or use backup)                  │
│    - DB_PASSWORD (set new secure password)                 │
│    - CLOUDFLARE_TUNNEL_TOKEN (new token for server B)       │
│    - APP_URL (new domain for server B)                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Import Database                                          │
│    docker exec -i laravel_db mysql \                       │
│      -u root -p"${DB_PASSWORD}" \                          │
│      ${DB_DATABASE} < dump.sql                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. Restore Storage Files                                    │
│    cp -r /tmp/migration-restore/storage/* storage/        │
│    chown -R www-data:www-data storage                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. Start Containers                                         │
│    docker compose up -d                                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 8. Verify Restore                                           │
│    - Check database rows count                            │
│    - Verify storage files exist                           │
│    - Test application URL                                  │
└─────────────────────────────────────────────────────────────┘
```

---

## Error Handling

### Backup Error Handling

| Scenario | Action |
|----------|--------|
| Insufficient disk space | Check space required, warn user, exit |
| Database dump fails | Show mysqldump error, cleanup temp, exit |
| File copy fails | Show which file failed, cleanup temp, exit |
| Compression fails | Show tar error, cleanup temp, exit |
| Container not running | Warn to start containers, exit |

### Restore Error Handling

| Scenario | Action |
|----------|--------|
| Invalid backup file | Checksum mismatch, show error, exit |
| Version incompatible | Warn about potential issues, ask to continue |
| Database connection fails | Check DB credentials, show error, exit |
| SQL import fails | Show SQL error, offer partial import option |
| Container start fails | Show docker logs, offer troubleshooting |

### Rollback Capability

Restore script akan:
1. Backup existing .env sebelum overwrite
2. Create restore log untuk tracking
3. Jika critical error di mid-restore, offer rollback options

---

## Security Considerations

1. **Sensitive Keys in .env**
   - APP_KEY, DB_PASSWORD, CLOUDFLARE_TUNNEL_TOKEN, dll
   - Di-backup file, sensitive keys akan di-mask: `APP_KEY=***MASKED***`
   - Restore script akan prompt user untuk input values baru

2. **Backup File Access**
   - Backup files disimpan di `/backups/` dengan permission `600`
   - User di-warn untuk transfer via secure channel (scp, sftp)

3. **Database Credentials**
   - DB_PASSWORD di-backup tapi di-mask di env-config
   - Restore script generate atau prompt password baru

---

## File Locations

### Script Locations
```
/scripts/
├── backup-migration.sh      # Backup script
└── restore-migration.sh      # Restore script
```

### Backup Output Location
```
/backups/
└── project-management-YYYY-MM-DD-HHMMSS.tar.gz
```

### Temporary Files
```
/tmp/migration-backup/    # During backup
/tmp/migration-restore/   # During restore
```

---

## Usage Examples

### Backup di Server A

```bash
# Pastikan Docker running
docker compose ps

# Jalankan backup
cd /path/to/project-management
bash scripts/backup-migration.sh

# Output:
# ✓ Checking prerequisites...
# ✓ Dumping database...
# ✓ Copying storage files...
# ✓ Compressing...
# 
# Backup created: /backups/project-management-2025-06-13-103000.tar.gz
# Size: 45.2 MB
# Database: nexabtn_management (12.3 MB)
# Storage: 32.9 MB
```

### Transfer ke Server B

```bash
# Dari lokal atau server A
scp /backups/project-management-2025-06-13-103000.tar.gz \
  user@server-b:/tmp/
```

### Restore di Server B

```bash
# Di server B, pastikan project sudah di-clone
cd /path/to/project-management

# Jalankan restore
bash scripts/restore-migration.sh /tmp/project-management-2025-06-13-103000.tar.gz

# Output:
# ✓ Checking prerequisites...
# ✓ Validating backup...
# ✓ Extracting archive...
# 
# Setup .env for new server:
#   APP_KEY [generate]: 
#   DB_PASSWORD: 
#   CLOUDFLARE_TUNNEL_TOKEN: 
#   APP_URL [https://new-domain.com]:
# 
# ✓ Importing database...
# ✓ Restoring storage files...
# ✓ Starting containers...
# 
# Restore complete! Visit https://new-domain.com/admin
```

---

## Testing Strategy

### Pre-Migration Testing

1. **Backup Test di Server A**
   - Run `backup-migration.sh`
   - Verify file created successfully
   - Check file size reasonable
   - Verify can extract tar.gz

2. **Restore Test di Staging (jika ada)**
   - Transfer backup ke staging
   - Run `restore-migration.sh` dengan `--dry-run`
   - Preview apa yang akan di-restore
   - Run restore sebenarnya
   - Verify aplikasi working

### Post-Migration Verification Checklist

Setelah restore di server B:

- [ ] Docker containers semua running
- [ ] Database connection successful
- [ ] Login admin works
- [ ] Dashboard shows correct data
- [ ] Projects & tickets count match
- [ ] Queue worker running
- [ ] Email service test send
- [ ] External access tokens working
- [ ] SSL via Cloudflare Tunnel active
- [ ] phpMyAdmin accessible (via SSH tunnel)

---

## Dependencies

### Required Tools
- `docker` & `docker compose`
- `mysqldump` (inside MariaDB container)
- `tar` & `gzip`
- `sha256sum` untuk checksums
- Basic Unix tools: `cp`, `mkdir`, `rm`, `cat`

### Existing Scripts
- `database/backups/backup-db.sh` — akan di-refactor sebagai bagian dari `backup-migration.sh`
- `database/backups/restore-db.sh` — akan di-refactor sebagai bagian dari `restore-migration.sh`

---

## Future Enhancements (Out of Scope)

- [ ] Scheduled automated backups (cron)
- [ ] Backup rotation & retention policy
- [ ] Encryption support untuk backup file
- [ ] Incremental backups
- [ ] Cloud storage integration (S3, GCS)
- [ ] Multi-environment sync (dev/staging/prod)
- [ ] Web UI untuk backup management

---

## Implementation Notes

1. Script harus idempotent — aman dijalankan berkali-kali
2. Progress indicators untuk long-running operations
3. Color-coded output (INFO, WARN, ERROR, SUCCESS)
4. Comprehensive error messages dengan troubleshooting hints
5. Script harus handle edge cases:
   - Container names yang berbeda
   - Custom volume names
   - Missing storage directories

---

## References

- Existing deployment: `DEPLOY.md`
- Docker setup: `docker-compose.yml`
- Current backup scripts: `database/backups/`

---

**Approved by:** User  
**Next Step:** Invoke writing-plans skill untuk create implementation plan
