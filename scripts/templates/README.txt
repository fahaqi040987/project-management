# DewaKoding Project Management - Migration Backup

This archive contains a complete backup of the Project Management application.

## Contents:
- database/dump.sql - Full MySQL database dump
- storage/ - Laravel storage files (uploads, cache, logs)
- env-config - Environment configuration (sensitive values masked)
- metadata.json - Backup information and checksums

## Restore Instructions:

1. Extract this archive on the new server:
   tar -xzf project-management-*.tar.gz

2. Navigate to project directory:
   cd /path/to/project-management

3. Run the restore script:
   bash scripts/restore-migration.sh /path/to/archive.tar.gz

4. Follow the interactive prompts to setup the new environment

## Important Notes:

- The .env file in this backup has sensitive values masked for security
- You will need to provide new values for: APP_KEY, DB_PASSWORD, CLOUDFLARE_TUNNEL_TOKEN
- Verify the backup integrity using: sha256sum <archive-file>
- Check metadata.json for backup details and checksums

## Backup Details:
Generated: {{BACKUP_DATE}}
Database: {{DB_NAME}}
Size: {{TOTAL_SIZE_BYTES}}
Hostname: {{HOSTNAME}}

For support, refer to the deployment documentation.
