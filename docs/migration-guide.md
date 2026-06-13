# Server Migration Guide

This guide covers how to migrate the DewaKoding Project Management application from one server to another.

## Prerequisites

**Source Server (Server A):**
- Docker and Docker Compose installed
- Application running
- At least 2x the current database/storage size free disk space

**Target Server (Server B):**
- Docker and Docker Compose installed
- Git installed
- Domain configured (if using Cloudflare Tunnel)

## Migration Process

### Step 1: Backup on Server A

1. SSH into the source server:
   ```bash
   ssh user@server-a
   cd /path/to/project-management
   ```

2. Run the backup script:
   ```bash
   bash scripts/backup-migration.sh
   ```

3. Note the backup file path, e.g.:
   ```
   /backups/project-management-2026-06-13-103000.tar.gz
   ```

4. Verify the backup:
   ```bash
   ls -lh backups/
   tar -tzf backups/project-management-*.tar.gz | head -20
   ```

### Step 2: Transfer to Server B

**Option A: Direct SCP (Server A → Server B)**
```bash
# From Server A
scp /backups/project-management-*.tar.gz user@server-b:/tmp/
```

**Option B: Via Local Machine**
```bash
# Download from Server A
scp user@server-a:/backups/project-management-*.tar.gz ./

# Upload to Server B
scp project-management-*.tar.gz user@server-b:/tmp/
```

**Option C: Via Cloud Storage**
```bash
# Upload to cloud storage (S3, GCS, etc.)
# Then download on Server B
```

### Step 3: Prepare Server B

1. SSH into the target server:
   ```bash
   ssh user@server-b
   ```

2. Clone the repository:
   ```bash
   cd /opt  # or your preferred location
   git clone https://github.com/SeptiawanAjiP/dewakoding-project-management project-management
   cd project-management
   ```

3. Verify backup file:
   ```bash
   ls -lh /tmp/project-management-*.tar.gz
   ```

### Step 4: Restore on Server B

1. Run the restore script:
   ```bash
   bash scripts/restore-migration.sh /tmp/project-management-*.tar.gz
   ```

2. Follow the prompts:
   - The script will automatically extract the backup
   - Existing .env will be backed up
   - Database will be imported
   - Storage files will be restored
   - Containers will be started

3. Update sensitive values in .env:
   ```bash
   nano .env
   # Update these values:
   # - APP_KEY (run: docker compose exec app php artisan key:generate)
   # - DB_PASSWORD
   # - CLOUDFLARE_TUNNEL_TOKEN (if using Cloudflare Tunnel)
   # - APP_URL (new domain)
   ```

4. Restart containers:
   ```bash
   docker compose restart
   ```

5. Verify the restore:
   ```bash
   docker compose ps
   curl -I https://your-domain.com/admin
   ```

### Step 5: Post-Migration Verification

1. Test admin login at `https://your-domain.com/admin`

2. Verify data:
   - Check project count
   - Check ticket count
   - Verify user accounts

3. Test functionality:
   - Create a test ticket
   - Test file upload (if applicable)
   - Verify queue worker is running

4. Check logs:
   ```bash
   docker compose logs -f
   ```

## Troubleshooting

### Backup Issues

**"Database dump failed"**
- Check database container is running: `docker compose ps db`
- Verify DB_PASSWORD in .env
- Check database logs: `docker compose logs db`

**"Insufficient disk space"**
- Check available space: `df -h`
- Clean up old backups: `rm backups/old-*`
- Consider skipping storage if not needed

**"Container not found"**
- Start containers: `docker compose up -d`
- Check container names: `docker compose ps`

### Restore Issues

**"Invalid gzip file"**
- Re-transfer the backup file
- Verify checksum: `sha256sum backup.tar.gz`

**"Database import failed"**
- Verify .env DB_PASSWORD is correct
- Check database container is healthy
- Review SQL dump for errors

**"Application not responding"**
- Check container status: `docker compose ps`
- Review logs: `docker compose logs app nginx`
- Verify APP_URL in .env

**"Permission denied on storage"**
```bash
sudo chown -R www-data:www-data storage/
chmod -R 775 storage/
```

## Rollback

If restore fails, you can rollback:

1. On Server B:
   ```bash
   docker compose down
   sudo rm -rf storage/ database/
   mv storage.backup.* storage/
   mv .env.backup.* .env
   docker compose up -d
   ```

2. Restore from backup again or investigate the issue

## Advanced Options

### Partial Backup (Database Only)
```bash
bash scripts/backup-migration.sh --skip-storage
```

### Partial Restore (Database Only)
```bash
bash scripts/restore-migration.sh backup.tar.gz --skip-storage
```

### Dry Run (Preview Only)
```bash
bash scripts/restore-migration.sh backup.tar.gz --dry-run
```

### Quiet Backup (Minimal Output)
```bash
bash scripts/backup-migration.sh --quiet
```

## Security Considerations

1. **Backup Files**: Delete backup files after successful migration
2. **.env File**: Contains sensitive keys - keep it secure
3. **Transfer**: Use SCP or SFTP for secure transfer
4. **Passwords**: Generate strong passwords for the new server
5. **Access**: Restrict SSH access to authorized users only

## Checklist

### Pre-Migration
- [ ] Verify source server backup works
- [ ] Check target server prerequisites
- [ ] Secure backup transfer method
- [ ] Plan for minimal downtime

### During Migration
- [ ] Complete backup on Server A
- [ ] Verify backup file integrity
- [ ] Successful transfer to Server B
- [ ] Restore completes without errors

### Post-Migration
- [ ] Update sensitive values in .env
- [ ] Admin login works
- [ ] All data present (projects, tickets, users)
- [ ] Queue worker running
- [ ] Email functioning (if configured)
- [ ] SSL/HTTPS working
- [ ] Clean up backup files
- [ ] Update DNS (if applicable)

## Additional Resources

- Deployment Guide: `DEPLOY.md`
- Docker Compose: `docker-compose.yml`
- Environment Config: `.env.production.example`
- Troubleshooting: Check container logs with `docker compose logs -f`
