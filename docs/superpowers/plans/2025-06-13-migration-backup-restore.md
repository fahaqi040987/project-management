# Migration Backup/Restore Tools Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create comprehensive backup/restore tools for full server migration of DewaKoding Project Management application

**Architecture:** Two bash scripts that backup (database + storage + config) to compressed archive, and restore with interactive setup for new server environment

**Tech Stack:** Bash, Docker, MySQL/MariaDB, tar/gzip

---

## File Structure

**New Files:**
- `/scripts/backup-migration.sh` - Comprehensive backup script
- `/scripts/restore-migration.sh` - Comprehensive restore script
- `/scripts/lib/migration-helpers.sh` - Shared utility functions
- `/scripts/templates/metadata.json.template` - Metadata template
- `/scripts/templates/README.txt` - Restore instructions template

**Existing Files (no changes needed):**
- `/database/backups/backup-db.sh` - Legacy, leave as-is
- `/database/backups/restore-db.sh` - Legacy, leave as-is

---

## Task 1: Create Directory Structure

**Files:**
- Create: `/scripts/`
- Create: `/scripts/lib/`
- Create: `/scripts/templates/`
- Create: `/backups/`

- [ ] **Step 1: Create scripts directory structure**

```bash
mkdir -p scripts/lib scripts/templates backups
```

- [ ] **Step 2: Verify directories created**

Run: `ls -la scripts/`
Expected: Output showing `lib/` and `templates/` subdirectories

- [ ] **Step 3: Set proper permissions**

```bash
chmod 755 scripts scripts/lib scripts/templates backups
```

- [ ] **Step 4: Commit**

```bash
git add scripts/ backups/
git commit -m "feat: create directory structure for migration scripts"
```

---

## Task 2: Create Shared Helper Library

**Files:**
- Create: `/scripts/lib/migration-helpers.sh`

- [ ] **Step 1: Write helper functions library**

```bash
#!/bin/bash
# scripts/lib/migration-helpers.sh
# Shared utility functions for migration scripts

# Color output functions
info()    { printf "\033[1;34m[INFO]\033[0m  %s\n" "$1"; }
success() { printf "\033[1;32m[OK]\033[0m    %s\n" "$1"; }
warn()    { printf "\033[1;33m[WARN]\033[0m  %s\n" "$1"; }
error()   { printf "\033[1;31m[ERROR]\033[0m %s\n" "$1" >&2; }
step()    { printf "\n\033[1;36m[%s]\033[0m %s\n" "$1" "$2"; }

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Check Docker is running
docker_running() {
    docker info &>/dev/null
}

# Get database container name
get_db_container() {
    docker compose ps -q db 2>/dev/null | head -1 | xargs docker inspect --format='{{.Name}}' | sed 's/\///'
}

# Get app container name
get_app_container() {
    docker compose ps -q app 2>/dev/null | head -1 | xargs docker inspect --format='{{.Name}}' | sed 's/\///'
}

# Get database name from .env
get_db_name() {
    grep "^DB_DATABASE=" .env 2>/dev/null | cut -d'=' -f2
}

# Get database password from .env
get_db_password() {
    grep "^DB_PASSWORD=" .env 2>/dev/null | cut -d'=' -f2
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes} B"
    elif [ "$bytes" -lt 1048576 ]; then
        echo "$((bytes / 1024)) KB"
    elif [ "$bytes" -lt 1073741824 ]; then
        echo "$((bytes / 1048576)) MB"
    else
        echo "$((bytes / 1073741824)) GB"
    fi
}

# Calculate file checksum
calculate_checksum() {
    sha256sum "$1" | cut -d' ' -f1
}

# Validate .env file exists and has required keys
validate_env_file() {
    if [ ! -f ".env" ]; then
        error ".env file not found!"
        return 1
    fi
    
    local required_vars=("DB_DATABASE" "DB_USERNAME" "DB_PASSWORD" "DB_HOST")
    local missing=()
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" .env; then
            missing+=("$var")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required .env variables: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Mask sensitive values in .env for backup
mask_env_sensitive() {
    local input_file="$1"
    local output_file="$2"
    local sensitive_keys=("APP_KEY" "DB_PASSWORD" "CLOUDFLARE_TUNNEL_TOKEN" "MAIL_PASSWORD" "GOOGLE_CLIENT_SECRET")
    
    cp "$input_file" "$output_file"
    
    for key in "${sensitive_keys[@]}"; do
        sed -i "s/^${key}=.*/${key}=***MASKED***/" "$output_file"
    done
}

# Generate random password
generate_password() {
    openssl rand -base64 24 | tr -d '=/+' | head -c 32
}

# Prompt user for input with default
prompt_input() {
    local var_name="$1"
    local prompt_text="$2"
    local default_value="${3:-}"
    local is_sensitive="${4:-false}"
    
    if [ -n "$default_value" ]; then
        printf "  %s [%s]: " "$prompt_text" "$default_value"
    else
        printf "  %s: " "$prompt_text"
    fi
    
    if [ "$is_sensitive" = "true" ]; then
        read -rs value
        echo
    else
        read -r value
    fi
    
    value="${value:-$default_value}"
    printf -v "$var_name" '%s' "$value"
}

# Check disk space
check_disk_space() {
    local required_mb=$1
    local available_mb=$(df -BM --output=avail . | tail -1 | tr -d 'M')
    
    if [ "$available_mb" -lt "$required_mb" ]; then
        error "Insufficient disk space. Required: ${required_mb}MB, Available: ${available_mb}MB"
        return 1
    fi
    return 0
}

# Cleanup temporary files
cleanup_temp() {
    local temp_dir="$1"
    if [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
        info "Cleaned up temporary directory: $temp_dir"
    fi
}
```

- [ ] **Step 2: Source and test helper functions**

```bash
# Test the functions
source scripts/lib/migration-helpers.sh

# Test color output
info "Test info message"
success "Test success message"
warn "Test warning message"
error "Test error message"

# Test command_exists
if command_exists docker; then
    success "Docker found"
else
    error "Docker not found"
fi
```

- [ ] **Step 3: Verify helper functions work**

Run: `bash -c 'source scripts/lib/migration-helpers.sh && info "Test"'`
Expected: Output "[INFO]  Test" in blue

- [ ] **Step 4: Commit**

```bash
git add scripts/lib/migration-helpers.sh
git commit -m "feat: add shared helper library for migration scripts"
```

---

## Task 3: Create Metadata Template

**Files:**
- Create: `/scripts/templates/metadata.json.template`

- [ ] **Step 1: Write metadata JSON template**

```json
{
  "backup_date": "{{BACKUP_DATE}}",
  "version": "1.0.0",
  "database_name": "{{DB_NAME}}",
  "database_size_bytes": {{DB_SIZE}},
  "storage_size_bytes": {{STORAGE_SIZE}},
  "total_size_bytes": {{TOTAL_SIZE}},
  "checksum": "{{CHECKSUM}}",
  "hostname": "{{HOSTNAME}}",
  "app_url": "{{APP_URL}}",
  "compressed_file": "{{ARCHIVE_NAME}}"
}
```

- [ ] **Step 2: Create README template for restore**

Create: `/scripts/templates/README.txt`

```bash
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
```

- [ ] **Step 3: Commit templates**

```bash
git add scripts/templates/
git commit -m "feat: add metadata and README templates for migration"
```

---

## Task 4: Create Backup Script - Prerequisites Check

**Files:**
- Create: `/scripts/backup-migration.sh`

- [ ] **Step 1: Write script header and prerequisites check**

```bash
#!/bin/bash
# scripts/backup-migration.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/migration-helpers.sh"

# Configuration
BACKUP_DIR="$PROJECT_ROOT/backups"
TEMP_DIR="/tmp/migration-backup-$$"
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
BACKUP_NAME="project-management-$TIMESTAMP.tar.gz"
METADATA_FILE="$TEMP_DIR/metadata.json"

# Parse arguments
SKIP_DATABASE=false
SKIP_STORAGE=false
QUIET=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --skip-database) SKIP_DATABASE=true ;;
        --skip-storage) SKIP_STORAGE=true ;;
        --quiet|-q) QUIET=true ;;
        --help|-h)
            echo "Usage: bash backup-migration.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-database   Skip database backup"
            echo "  --skip-storage    Skip storage files backup"
            echo "  --quiet, -q       Minimal output"
            echo "  --help, -h        Show this help"
            exit 0
            ;;
        *) error "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# Header
if [ "$QUIET" = "false" ]; then
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  DewaKoding Project Management — Backup Migration"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
fi

# Change to project root
cd "$PROJECT_ROOT"

# ── Step 1: Check Prerequisites ────────────────────────────────────────
step "1/8" "Checking prerequisites..."

# Check if .env exists
if ! validate_env_file; then
    error "Environment validation failed"
    exit 1
fi
success "Environment validated"

# Check Docker
if ! command_exists docker; then
    error "Docker not found. Install: https://docs.docker.com/get-docker/"
    exit 1
fi
success "Docker: $(docker --version | cut -d' ' -f3)"

# Check Docker Compose
if ! docker compose version &>/dev/null; then
    error "Docker Compose not found"
    exit 1
fi
success "Docker Compose: $(docker compose version --short)"

# Check Docker running
if ! docker_running; then
    error "Docker is not running. Start Docker first."
    exit 1
fi
success "Docker is running"

# Check required tools
for tool in tar gzip mysqldump sha256sum; do
    if ! command_exists "$tool"; then
        error "Required tool not found: $tool"
        exit 1
    fi
done
success "Required tools: OK"

# Check containers running
DB_CONTAINER=$(get_db_container)
if [ -z "$DB_CONTAINER" ]; then
    error "Database container not found. Run: docker compose up -d"
    exit 1
fi
success "Database container: $DB_CONTAINER"

APP_CONTAINER=$(get_app_container)
if [ -z "$APP_CONTAINER" ]; then
    warn "App container not found (may not be running)"
else
    success "App container: $APP_CONTAINER"
fi

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"
success "Backup directory: $BACKUP_DIR"

info "Prerequisites check complete"
```

- [ ] **Step 2: Test prerequisites check**

```bash
# Make executable
chmod +x scripts/backup-migration.sh

# Test prerequisites
bash scripts/backup-migration.sh 2>&1 | head -20
```

Expected: Should show prerequisites check passing

- [ ] **Step 3: Commit**

```bash
git add scripts/backup-migration.sh
git commit -m "feat: add prerequisites check to backup script"
```

---

## Task 5: Create Backup Script - Database Dump

**Files:**
- Modify: `/scripts/backup-migration.sh`

- [ ] **Step 1: Add database dump functionality**

Add after the prerequisites check:

```bash
# ── Step 2: Prepare Temporary Directory ────────────────────────────────
step "2/8" "Preparing temporary directory..."

mkdir -p "$TEMP_DIR/database"
mkdir -p "$TEMP_DIR/storage"
success "Temp directory: $TEMP_DIR"

# ── Step 3: Database Dump ───────────────────────────────────────────────
if [ "$SKIP_DATABASE" = "false" ]; then
    step "3/8" "Dumping database..."
    
    DB_NAME=$(get_db_name)
    DB_PASSWORD=$(get_db_password)
    
    if [ -z "$DB_NAME" ]; then
        error "Cannot determine database name from .env"
        cleanup_temp "$TEMP_DIR"
        exit 1
    fi
    
    info "Database: $DB_NAME"
    
    # Dump database
    if ! docker exec "$DB_CONTAINER" mysqldump \
        -u root \
        -p"${DB_PASSWORD}" \
        --single-transaction \
        --quick \
        --lock-tables=false \
        "$DB_NAME" > "$TEMP_DIR/database/dump.sql" 2>/dev/null; then
        
        error "Database dump failed. Check DB credentials and container status."
        cleanup_temp "$TEMP_DIR"
        exit 1
    fi
    
    # Verify dump is not empty
    if [ ! -s "$TEMP_DIR/database/dump.sql" ]; then
        error "Database dump is empty!"
        cleanup_temp "$TEMP_DIR"
        exit 1
    fi
    
    DB_SIZE=$(wc -c < "$TEMP_DIR/database/dump.sql")
    success "Database dumped: $(format_bytes $DB_SIZE)"
else
    warn "Skipping database dump (--skip-database)"
    DB_SIZE=0
fi
```

- [ ] **Step 2: Test database dump**

```bash
# Test the database dump portion
bash -x scripts/backup-migration.sh 2>&1 | grep -A5 "Step 3"
```

Expected: Database dump should complete successfully

- [ ] **Step 3: Commit**

```bash
git add scripts/backup-migration.sh
git commit -m "feat: add database dump functionality to backup script"
```

---

## Task 6: Create Backup Script - Storage Files Copy

**Files:**
- Modify: `/scripts/backup-migration.sh`

- [ ] **Step 1: Add storage files copy functionality**

Add after the database dump section:

```bash
# ── Step 4: Copy Storage Files ─────────────────────────────────────────
if [ "$SKIP_STORAGE" = "false" ]; then
    step "4/8" "Copying storage files..."
    
    STORAGE_SOURCE="$PROJECT_ROOT/storage"
    
    if [ ! -d "$STORAGE_SOURCE" ]; then
        warn "Storage directory not found: $STORAGE_SOURCE"
        STORAGE_SIZE=0
    else
        # Copy storage subdirectories
        for subdir in app framework logs; do
            if [ -d "$STORAGE_SOURCE/$subdir" ]; then
                info "Copying storage/$subdir..."
                cp -r "$STORAGE_SOURCE/$subdir" "$TEMP_DIR/storage/"
                
                subdir_size=$(du -sb "$TEMP_DIR/storage/$subdir" 2>/dev/null | cut -f1)
                info "  $(format_bytes $subdir_size)"
            else
                info "Skipping storage/$subdir (not found)"
            fi
        done
        
        STORAGE_SIZE=$(du -sb "$TEMP_DIR/storage" 2>/dev/null | cut -f1)
        success "Storage files copied: $(format_bytes $STORAGE_SIZE)"
    fi
else
    warn "Skipping storage files (--skip-storage)"
    STORAGE_SIZE=0
fi
```

- [ ] **Step 2: Test storage files copy**

```bash
# Test storage copy
bash scripts/backup-migration.sh 2>&1 | grep -A10 "Step 4"
```

Expected: Storage files should be copied

- [ ] **Step 3: Commit**

```bash
git add scripts/backup-migration.sh
git commit -m "feat: add storage files copy to backup script"
```

---

## Task 7: Create Backup Script - Configuration Copy

**Files:**
- Modify: `/scripts/backup-migration.sh`

- [ ] **Step 1: Add configuration copy functionality**

Add after storage copy section:

```bash
# ── Step 5: Copy Configuration ─────────────────────────────────────────
step "5/8" "Copying configuration..."

if [ -f ".env" ]; then
    mask_env_sensitive "$PROJECT_ROOT/.env" "$TEMP_DIR/env-config"
    success "Configuration copied (sensitive values masked)"
else
    error ".env file not found!"
    cleanup_temp "$TEMP_DIR"
    exit 1
fi

# Copy README template
if [ -f "$SCRIPT_DIR/templates/README.txt" ]; then
    # Replace placeholders
    BACKUP_DATE=$(date -Iseconds)
    APP_URL=$(grep "^APP_URL=" .env | cut -d'=' -f2)
    HOSTNAME=$(hostname)
    
    sed -e "s/{{BACKUP_DATE}}/$BACKUP_DATE/g" \
        -e "s/{{DB_NAME}}/$DB_NAME/g" \
        -e "s/{{HOSTNAME}}/$HOSTNAME/g" \
        "$SCRIPT_DIR/templates/README.txt" > "$TEMP_DIR/README.txt"
    
    success "README.txt generated"
else
    warn "README template not found, skipping"
fi
```

- [ ] **Step 2: Test configuration copy**

```bash
# Test config copy
bash scripts/backup-migration.sh 2>&1 | grep -A5 "Step 5"
```

Expected: Configuration should be copied with sensitive values masked

- [ ] **Step 3: Verify masked values**

```bash
# Check that sensitive values are masked in the backup
grep "APP_KEY=\|DB_PASSWORD=" /tmp/migration-backup-*/env-config
```

Expected: Should show `***MASKED***` for sensitive values

- [ ] **Step 4: Commit**

```bash
git add scripts/backup-migration.sh
git commit -m "feat: add configuration copy to backup script"
```

---

## Task 8: Create Backup Script - Metadata Generation

**Files:**
- Modify: `/scripts/backup-migration.sh`

- [ ] **Step 1: Add metadata generation functionality**

Add after configuration copy section:

```bash
# ── Step 6: Generate Metadata ───────────────────────────────────────────
step "6/8" "Generating metadata..."

TOTAL_SIZE=$((DB_SIZE + STORAGE_SIZE))
BACKUP_DATE=$(date -Iseconds)
HOSTNAME=$(hostname)
APP_URL=$(grep "^APP_URL=" .env | cut -d'=' -f2)

if [ -f "$SCRIPT_DIR/templates/metadata.json.template" ]; then
    # Replace placeholders in template
    sed -e "s/{{BACKUP_DATE}}/$BACKUP_DATE/g" \
        -e "s/{{DB_NAME}}/$DB_NAME/g" \
        -e "s/{{DB_SIZE}}/$DB_SIZE/g" \
        -e "s/{{STORAGE_SIZE}}/$STORAGE_SIZE/g" \
        -e "s/{{TOTAL_SIZE}}/$TOTAL_SIZE/g" \
        -e "s/{{HOSTNAME}}/$HOSTNAME/g" \
        -e "s/{{APP_URL}}/$APP_URL/g" \
        -e "s/{{ARCHIVE_NAME}}/$BACKUP_NAME/g" \
        "$SCRIPT_DIR/templates/metadata.json.template" > "$METADATA_FILE"
    
    # Calculate checksum (will be updated after compression)
    echo '"checksum": "sha256:CALCULATING",' >> "$METADATA_FILE"
    
    success "Metadata generated"
else
    warn "Metadata template not found, creating minimal metadata"
    cat > "$METADATA_FILE" <<EOF
{
  "backup_date": "$BACKUP_DATE",
  "database_name": "$DB_NAME",
  "database_size_bytes": $DB_SIZE,
  "storage_size_bytes": $STORAGE_SIZE,
  "total_size_bytes": $TOTAL_SIZE,
  "hostname": "$HOSTNAME",
  "app_url": "$APP_URL"
}
EOF
fi
```

- [ ] **Step 2: Test metadata generation**

```bash
# Test metadata generation
bash scripts/backup-migration.sh 2>&1 | grep -A5 "Step 6"
cat /tmp/migration-backup-*/metadata.json
```

Expected: Valid JSON with backup information

- [ ] **Step 3: Commit**

```bash
git add scripts/backup-migration.sh
git commit -m "feat: add metadata generation to backup script"
```

---

## Task 9: Create Backup Script - Compression

**Files:**
- Modify: `/scripts/backup-migration.sh`

- [ ] **Step 1: Add compression functionality**

Add after metadata generation:

```bash
# ── Step 7: Compress Archive ────────────────────────────────────────────
step "7/8" "Compressing archive..."

# Check disk space
ESTIMATED_SIZE=$((TOTAL_SIZE * 2 / 1024 / 1024))  # Rough estimate in MB
if ! check_disk_space "$ESTIMATED_SIZE"; then
    error "Insufficient disk space for compression"
    cleanup_temp "$TEMP_DIR"
    exit 1
fi

# Create compressed archive
ARCHIVE_PATH="$BACKUP_DIR/$BACKUP_NAME"

if ! tar -czf "$ARCHIVE_PATH" -C "$TEMP_DIR" . 2>/dev/null; then
    error "Failed to create compressed archive"
    cleanup_temp "$TEMP_DIR"
    exit 1
fi

# Get final archive size
ARCHIVE_SIZE=$(wc -c < "$ARCHIVE_PATH")

# Calculate checksum
CHECKSUM=$(calculate_checksum "$ARCHIVE_PATH")

# Update metadata with checksum
sed -i "s/sha256:CALCULATING/sha256:$CHECKSUM/" "$METADATA_FILE"

# Update metadata file in archive (if possible, otherwise skip)
success "Archive created: $ARCHIVE_NAME"
success "Archive size: $(format_bytes $ARCHIVE_SIZE)"
success "Checksum: sha256:$CHECKSUM"
```

- [ ] **Step 2: Test compression**

```bash
# Test compression
bash scripts/backup-migration.sh 2>&1 | grep -A10 "Step 7"

# Verify archive was created
ls -lh backups/*.tar.gz | tail -1
```

Expected: Compressed archive created in backups/ directory

- [ ] **Step 3: Verify archive integrity**

```bash
# Test extracting the archive
tar -tzf backups/project-management-*.tar.gz | head -20
```

Expected: Should list files in archive (database/dump.sql, storage/, etc.)

- [ ] **Step 4: Commit**

```bash
git add scripts/backup-migration.sh
git commit -m "feat: add compression functionality to backup script"
```

---

## Task 10: Create Backup Script - Finalize

**Files:**
- Modify: `/scripts/backup-migration.sh`

- [ ] **Step 1: Add cleanup and report**

Add as the final section:

```bash
# ── Step 8: Cleanup and Report ───────────────────────────────────────────
step "8/8" "Finalizing backup..."

# Cleanup temp directory
cleanup_temp "$TEMP_DIR"

# Final report
if [ "$QUIET" = "false" ]; then
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    success "BACKUP COMPLETE!"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    info "Archive: $ARCHIVE_PATH"
    info "Size: $(format_bytes $ARCHIVE_SIZE)"
    info "Checksum: $CHECKSUM"
    echo ""
    info "Database: $DB_NAME ($(format_bytes $DB_SIZE))"
    info "Storage: $(format_bytes $STORAGE_SIZE)"
    echo ""
    info "Transfer to new server:"
    echo "  scp $ARCHIVE_PATH user@new-server:/tmp/"
    echo ""
    info "Restore on new server:"
    echo "  bash scripts/restore-migration.sh /tmp/$BACKUP_NAME"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
fi
```

- [ ] **Step 2: Test full backup script**

```bash
# Run full backup
bash scripts/backup-migration.sh
```

Expected: Complete backup with all steps and final report

- [ ] **Step 3: Verify backup archive**

```bash
# List archive contents
tar -tzf backups/project-management-*.tar.gz

# Verify database dump exists
tar -xzOf backups/project-management-*.tar.gz database/dump.sql | head -20

# Verify metadata
tar -xzOf backups/project-management-*.tar.gz metadata.json | jq .
```

Expected: All files present and valid

- [ ] **Step 4: Commit**

```bash
git add scripts/backup-migration.sh
git commit -m "feat: complete backup script with cleanup and reporting"
```

---

## Task 11: Create Restore Script - Header and Validation

**Files:**
- Create: `/scripts/restore-migration.sh`

- [ ] **Step 1: Write restore script header and argument parsing**

```bash
#!/bin/bash
# scripts/restore-migration.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/migration-helpers.sh"

# Parse arguments
BACKUP_FILE=""
DRY_RUN=false
SKIP_DATABASE=false
SKIP_STORAGE=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true ;;
        --skip-database) SKIP_DATABASE=true ;;
        --skip-storage) SKIP_STORAGE=true ;;
        --help|-h)
            echo "Usage: bash restore-migration.sh <backup-file.tar.gz> [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run         Preview what will be restored without making changes"
            echo "  --skip-database    Skip database restore"
            echo "  --skip-storage     Skip storage restore"
            echo "  --help, -h         Show this help"
            exit 0
            ;;
        *) 
            if [ -z "$BACKUP_FILE" ]; then
                BACKUP_FILE="$1"
            else
                error "Unknown argument: $1"
                exit 1
            fi
            ;;
    esac
    shift
done

# Check backup file provided
if [ -z "$BACKUP_FILE" ]; then
    error "Backup file not specified!"
    echo "Usage: bash restore-migration.sh <backup-file.tar.gz>"
    exit 1
fi

# Check backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    error "Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Header
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  DewaKoding Project Management — Restore Migration"
echo "════════════════════════════════════════════════════════════════"
echo ""
info "Backup file: $BACKUP_FILE"
if [ "$DRY_RUN" = "true" ]; then
    warn "DRY RUN MODE - No changes will be made"
fi
echo ""

# Change to project root
cd "$PROJECT_ROOT"

# ── Step 1: Validate Backup ───────────────────────────────────────────
step "1/9" "Validating backup file..."

# Verify it's a valid gzip file
if ! gzip -t "$BACKUP_FILE" 2>/dev/null; then
    error "Invalid gzip file: $BACKUP_FILE"
    exit 1
fi
success "Archive format: Valid gzip"

# Extract metadata for validation
TEMP_DIR="/tmp/migration-restore-$$"
mkdir -p "$TEMP_DIR"

# Extract just metadata.json
if ! tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR" metadata.json 2>/dev/null; then
    warn "Could not extract metadata.json (may be old backup format)"
    METADATA_VALID=false
else
    METADATA_VALID=true
    
    # Read metadata
    if command_exists jq; then
        info "Backup details:"
        jq -r '"  Database: \(.database_name // "unknown")"' "$TEMP_DIR/metadata.json" 2>/dev/null || true
        jq -r '"  Size: \(.total_size_bytes // "unknown") bytes"' "$TEMP_DIR/metadata.json" 2>/dev/null || true
        jq -r '"  Date: \(.backup_date // "unknown")"' "$TEMP_DIR/metadata.json" 2>/dev/null || true
        jq -r '"  Hostname: \(.hostname // "unknown")"' "$TEMP_DIR/metadata.json" 2>/dev/null || true
    fi
    
    success "Metadata validated"
fi

# Calculate and verify checksum if available
if [ "$METADATA_VALID" = "true" ] && command_exists jq; then
    EXPECTED_CHECKSUM=$(jq -r '.checksum' "$TEMP_DIR/metadata.json" 2>/dev/null | sed 's/sha256://')
    if [ "$EXPECTED_CHECKSUM" != "null" ] && [ -n "$EXPECTED_CHECKSUM" ]; then
        ACTUAL_CHECKSUM=$(sha256sum "$BACKUP_FILE" | cut -d' ' -f1)
        if [ "$EXPECTED_CHECKSUM" = "$ACTUAL_CHECKSUM" ]; then
            success "Checksum verified"
        else
            warn "Checksum mismatch!"
            info "Expected: $EXPECTED_CHECKSUM"
            info "Actual: $ACTUAL_CHECKSUM"
            read -r -p "  Continue anyway? [y/N]: " continue_mismatch
            if [[ ! "${continue_mismatch}" =~ ^[Yy]$ ]]; then
                error "Restore cancelled due to checksum mismatch"
                rm -rf "$TEMP_DIR"
                exit 1
            fi
        fi
    fi
fi

success "Backup file validated"
```

- [ ] **Step 2: Test validation**

```bash
# Make executable
chmod +x scripts/restore-migration.sh

# Test validation with the backup we created
bash scripts/restore-migration.sh backups/project-management-*.tar.gz --dry-run
```

Expected: Should validate the backup file and show metadata

- [ ] **Step 3: Commit**

```bash
git add scripts/restore-migration.sh
git commit -m "feat: add header and validation to restore script"
```

---

## Task 12: Create Restore Script - Extract Archive

**Files:**
- Modify: `/scripts/restore-migration.sh`

- [ ] **Step 1: Add extraction functionality**

Add after validation section:

```bash
# ── Step 2: Extract Archive ─────────────────────────────────────────────
step "2/9" "Extracting archive..."

# Extract full archive
if ! tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR" 2>/dev/null; then
    error "Failed to extract archive"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Verify extracted contents
if [ ! -d "$TEMP_DIR/database" ] && [ ! -d "$TEMP_DIR/storage" ]; then
    error "Archive does not contain expected directories"
    rm -rf "$TEMP_DIR"
    exit 1
fi

success "Archive extracted to: $TEMP_DIR"

if [ "$DRY_RUN" = "true" ]; then
    info "Contents of backup:"
    ls -la "$TEMP_DIR"
    echo ""
    warn "Dry run complete - exiting"
    rm -rf "$TEMP_DIR"
    exit 0
fi
```

- [ ] **Step 2: Test extraction**

```bash
# Test extraction (dry-run)
bash scripts/restore-migration.sh backups/project-management-*.tar.gz --dry-run
```

Expected: Should show extracted contents

- [ ] **Step 3: Verify extraction directory**

```bash
# Manual extraction test
mkdir -p /tmp/test-restore
tar -xzf backups/project-management-*.tar.gz -C /tmp/test-restore
ls -la /tmp/test-restore
rm -rf /tmp/test-restore
```

Expected: Should show database/, storage/, env-config, etc.

- [ ] **Step 4: Commit**

```bash
git add scripts/restore-migration.sh
git commit -m "feat: add archive extraction to restore script"
```

---

## Task 13: Create Restore Script - Environment Setup

**Files:**
- Modify: `/scripts/restore-migration.sh`

- [ ] **Step 1: Add environment setup functionality**

Add after extraction section:

```bash
# ── Step 3: Setup Environment ──────────────────────────────────────────
step "3/9" "Setting up environment..."

# Check if .env already exists
if [ -f ".env" ]; then
    warn ".env file already exists"
    read -r -p "  Backup existing .env? [Y/n]: " backup_env
    if [[ "${backup_env:-Y}" =~ ^[Yy]$ ]]; then
        cp .env ".env.backup.$(date +%Y%m%d%H%M%S)"
        success "Existing .env backed up"
    else
        warn "Skipping .env backup"
    fi
fi

# Copy env-config from backup
if [ -f "$TEMP_DIR/env-config" ]; then
    cp "$TEMP_DIR/env-config" .env
    success "Environment config copied from backup"
else
    warn "env-config not found in backup, creating minimal .env"
    touch .env
fi

# Interactive prompts for sensitive values
echo ""
info "Configure sensitive values for new server:"
echo ""

# APP_KEY
EXISTING_APP_KEY=$(grep "^APP_KEY=" .env | cut -d'=' -f2)
if [ "$EXISTING_APP_KEY" = "***MASKED***" ] || [ -z "$EXISTING_APP_KEY" ]; then
    prompt_input NEW_APP_KEY "Generate new APP_KEY?" "generate"
    if [ "$NEW_APP_KEY" = "generate" ]; then
        NEW_APP_KEY=$(openssl rand -base64 32)
    fi
    sed -i "s/^APP_KEY=.*/APP_KEY=$NEW_APP_KEY/" .env
    success "APP_KEY configured"
else
    info "APP_KEY already set (using existing)"
fi

# DB_PASSWORD
EXISTING_DB_PASS=$(grep "^DB_PASSWORD=" .env | cut -d'=' -f2)
if [ "$EXISTING_DB_PASS" = "***MASKED***" ] || [ "$EXISTING_DB_PASS" = "GANTI_PASSWORD_KUAT_DISINI" ] || [ -z "$EXISTING_DB_PASS" ]; then
    prompt_input NEW_DB_PASS "Set new DB_PASSWORD" "" "true"
    if [ -z "$NEW_DB_PASS" ]; then
        NEW_DB_PASS=$(generate_password)
        warn "Generated random DB_PASSWORD: $NEW_DB_PASS"
    fi
    sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=$NEW_DB_PASS/" .env
    success "DB_PASSWORD configured"
else
    info "DB_PASSWORD already set (using existing)"
fi

# APP_URL
EXISTING_APP_URL=$(grep "^APP_URL=" .env | cut -d'=' -f2)
prompt_input NEW_APP_URL "Set APP_URL" "$EXISTING_APP_URL"
sed -i "s|^APP_URL=.*|APP_URL=$NEW_APP_URL|" .env
success "APP_URL configured"

# CLOUDFLARE_TUNNEL_TOKEN
EXISTING_TOKEN=$(grep "^CLOUDFLARE_TUNNEL_TOKEN=" .env | cut -d'=' -f2)
if [ "$EXISTING_TOKEN" = "***MASKED***" ] || [ "$EXISTING_TOKEN" = *"XXX"* ] || [ -z "$EXISTING_TOKEN" ]; then
    echo ""
    info "Cloudflare Tunnel Token required for production:"
    info "Get token from: Cloudflare Dashboard → Zero Trust → Networks → Tunnels"
    prompt_input NEW_TOKEN "Enter CLOUDFLARE_TUNNEL_TOKEN" "" "true"
    if [ -n "$NEW_TOKEN" ]; then
        sed -i "s|^CLOUDFLARE_TUNNEL_TOKEN=.*|CLOUDFLARE_TUNNEL_TOKEN=$NEW_TOKEN|" .env
        success "CLOUDFLARE_TUNNEL_TOKEN configured"
    else
        warn "CLOUDFLARE_TUNNEL_TOKEN not set (cloudflared container will not start)"
    fi
else
    info "CLOUDFLARE_TUNNEL_TOKEN already set"
fi

echo ""
success "Environment configuration complete"
```

- [ ] **Step 2: Test environment setup**

```bash
# Test environment setup (this will modify .env, so backup it first!)
cp .env .env.test-backup

# Run with dry-run to see prompts (cancel before making changes)
# bash scripts/restore-migration.sh backups/project-management-*.tar.gz
```

Expected: Should prompt for sensitive values

- [ ] **Step 3: Restore test .env**

```bash
# Restore original .env
mv .env.test-backup .env
```

- [ ] **Step 4: Commit**

```bash
git add scripts/restore-migration.sh
git commit -m "feat: add environment setup to restore script"
```

---

## Task 14: Create Restore Script - Database Import

**Files:**
- Modify: `/scripts/restore-migration.sh`

- [ ] **Step 1: Add database import functionality**

Add after environment setup:

```bash
# ── Step 4: Database Import ─────────────────────────────────────────────
if [ "$SKIP_DATABASE" = "false" ]; then
    step "4/9" "Importing database..."
    
    DUMP_FILE="$TEMP_DIR/database/dump.sql"
    
    if [ ! -f "$DUMP_FILE" ]; then
        error "Database dump not found in backup: $DUMP_FILE"
        exit 1
    fi
    
    DB_NAME=$(get_db_name)
    DB_PASSWORD=$(get_db_password)
    
    info "Target database: $DB_NAME"
    
    # Check Docker containers
    if ! docker_running; then
        error "Docker is not running"
        exit 1
    fi
    
    DB_CONTAINER=$(get_db_container)
    if [ -z "$DB_CONTAINER" ]; then
        error "Database container not found. Run: docker compose up -d db"
        exit 1
    fi
    
    # Wait for database to be ready
    info "Waiting for database to be ready..."
    local retries=0
    local max_retries=30
    while [ $retries -lt $max_retries ]; do
        if docker exec "$DB_CONTAINER" mariadb-admin ping -h localhost -u root -p"${DB_PASSWORD}" &>/dev/null; then
            break
        fi
        retries=$((retries + 1))
        printf "  Waiting... (%ds/%ds)\r" "$((retries * 2))" "$((max_retries * 2))"
        sleep 2
    done
    echo ""
    
    if [ $retries -eq $max_retries ]; then
        error "Database not ready after 60s"
        exit 1
    fi
    success "Database is ready"
    
    # Import database
    info "Importing database dump (this may take a while)..."
    
    if ! cat "$DUMP_FILE" | docker exec -i "$DB_CONTAINER" mysql \
        -u root \
        -p"${DB_PASSWORD}" \
        "$DB_NAME" 2>/dev/null; then
        
        error "Database import failed!"
        info "Check database credentials and container logs"
        exit 1
    fi
    
    success "Database imported successfully"
    
    # Verify import
    TABLE_COUNT=$(docker exec "$DB_CONTAINER" mysql \
        -u root \
        -p"${DB_PASSWORD}" \
        "$DB_NAME" \
        -se "SHOW TABLES" 2>/dev/null | wc -l)
    
    if [ "$TABLE_COUNT" -gt 0 ]; then
        success "Database verified: $TABLE_COUNT tables"
    else
        warn "No tables found in database after import"
    fi
else
    warn "Skipping database import (--skip-database)"
fi
```

- [ ] **Step 2: Test database import**

```bash
# Test database import portion
# This requires a running database container
docker compose up -d db

# Test restore (this will modify the database!)
# bash scripts/restore-migration.sh backups/project-management-*.tar.gz
```

Expected: Database should be imported

- [ ] **Step 3: Verify database contents**

```bash
# Check tables in database
docker exec laravel_db mysql -u root -p"${DB_PASSWORD}" "${DB_DATABASE}" -se "SHOW TABLES"
```

Expected: Should list all tables (migrations, users, projects, tickets, etc.)

- [ ] **Step 4: Commit**

```bash
git add scripts/restore-migration.sh
git commit -m "feat: add database import to restore script"
```

---

## Task 15: Create Restore Script - Storage Restore

**Files:**
- Modify: `/scripts/restore-migration.sh`

- [ ] **Step 1: Add storage restore functionality**

Add after database import:

```bash
# ── Step 5: Restore Storage Files ───────────────────────────────────────
if [ "$SKIP_STORAGE" = "false" ]; then
    step "5/9" "Restoring storage files..."
    
    STORAGE_SOURCE="$TEMP_DIR/storage"
    STORAGE_TARGET="$PROJECT_ROOT/storage"
    
    if [ ! -d "$STORAGE_SOURCE" ]; then
        warn "Storage directory not found in backup"
    else
        # Backup existing storage
        if [ -d "$STORAGE_TARGET" ]; then
            info "Backing up existing storage..."
            mv "$STORAGE_TARGET" "${STORAGE_TARGET}.backup.$(date +%Y%m%d%H%M%S)"
        fi
        
        # Create storage directory structure
        mkdir -p "$STORAGE_TARGET"
        
        # Copy storage subdirectories
        for subdir in app framework logs; do
            if [ -d "$STORAGE_SOURCE/$subdir" ]; then
                info "Restoring storage/$subdir..."
                cp -r "$STORAGE_SOURCE/$subdir" "$STORAGE_TARGET/"
                
                subdir_size=$(du -sb "$STORAGE_TARGET/$subdir" 2>/dev/null | cut -f1)
                info "  $(format_bytes $subdir_size)"
            else
                info "Skipping storage/$subdir (not in backup)"
            fi
        done
        
        # Set proper permissions
        if [ -f "docker-compose.yml" ]; then
            # Try to determine the user from docker-compose
            WWW_USER="www-data"
        else
            WWW_USER="www-data"
        fi
        
        info "Setting storage permissions..."
        chown -R "$WWW_USER:$WWW_USER" "$STORAGE_TARGET" 2>/dev/null || \
            warn "Could not set ownership (may need manual: sudo chown -R www-data:www-data storage)"
        
        chmod -R 775 "$STORAGE_TARGET" 2>/dev/null || true
        
        STORAGE_SIZE=$(du -sb "$STORAGE_TARGET" 2>/dev/null | cut -f1)
        success "Storage files restored: $(format_bytes $STORAGE_SIZE)"
    fi
else
    warn "Skipping storage restore (--skip-storage)"
fi
```

- [ ] **Step 2: Test storage restore**

```bash
# Test storage restore portion
# This will copy files to storage/
# bash scripts/restore-migration.sh backups/project-management-*.tar.gz --skip-database
```

Expected: Storage files should be restored

- [ ] **Step 3: Verify storage contents**

```bash
# Check storage contents
ls -la storage/
du -sh storage/*
```

Expected: Should show restored app/, framework/, logs/ directories

- [ ] **Step 4: Commit**

```bash
git add scripts/restore-migration.sh
git commit -m "feat: add storage restore to restore script"
```

---

## Task 16: Create Restore Script - Container Restart

**Files:**
- Modify: `/scripts/restore-migration.sh`

- [ ] **Step 1: Add container restart functionality**

Add after storage restore:

```bash
# ── Step 6: Start Containers ────────────────────────────────────────────
step "6/9" "Starting containers..."

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    error "docker-compose.yml not found!"
    exit 1
fi

# Build and start containers
info "Building Docker images..."
if ! docker compose build 2>/dev/null; then
    warn "Docker build had issues, but continuing..."
fi

info "Starting containers..."
if ! docker compose up -d 2>/dev/null; then
    error "Failed to start containers"
    info "Check: docker compose logs"
    exit 1
fi

# Wait for app container
info "Waiting for containers to be ready..."
sleep 5

# Check container status
if docker compose ps | grep -q "Exit"; then
    error "Some containers exited unexpectedly"
    docker compose ps
    info "Check logs: docker compose logs"
    exit 1
fi

success "Containers started"
```

- [ ] **Step 2: Test container restart**

```bash
# Test container restart
# bash scripts/restore-migration.sh backups/project-management-*.tar.gz --skip-database --skip-storage
```

Expected: Containers should start

- [ ] **Step 3: Verify containers**

```bash
# Check container status
docker compose ps
```

Expected: All containers should be running

- [ ] **Step 4: Commit**

```bash
git add scripts/restore-migration.sh
git commit -m "feat: add container restart to restore script"
```

---

## Task 17: Create Restore Script - Verification

**Files:**
- Modify: `/scripts/restore-migration.sh`

- [ ] **Step 1: Add verification functionality**

Add as the final sections:

```bash
# ── Step 7: Verify Restore ────────────────────────────────────────────
step "7/9" "Verifying restore..."

# Database verification
if [ "$SKIP_DATABASE" = "false" ]; then
    DB_CONTAINER=$(get_db_container)
    DB_NAME=$(get_db_name)
    DB_PASSWORD=$(get_db_password)
    
    TABLE_COUNT=$(docker exec "$DB_CONTAINER" mysql \
        -u root \
        -p"${DB_PASSWORD}" \
        "$DB_NAME" \
        -se "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$DB_NAME'" 2>/dev/null)
    
    if [ "$TABLE_COUNT" -gt 0 ]; then
        success "Database verified: $TABLE_COUNT tables"
        
        # Check key tables
        KEY_TABLES="users projects tickets"
        for table in $KEY_TABLES; do
            ROWS=$(docker exec "$DB_CONTAINER" mysql \
                -u root \
                -p"${DB_PASSWORD}" \
                "$DB_NAME" \
                -se "SELECT COUNT(*) FROM $table" 2>/dev/null || echo "0")
            
            if [ "$ROWS" -gt 0 ]; then
                info "  ✓ $table: $ROWS rows"
            else
                warn "  ✗ $table: table not found or empty"
            fi
        done
    else
        warn "Database verification failed - no tables found"
    fi
fi

# Storage verification
if [ "$SKIP_STORAGE" = "false" ]; then
    if [ -d "storage/app" ] || [ -d "storage/framework" ] || [ -d "storage/logs" ]; then
        success "Storage directories present"
    else
        warn "Some storage directories missing"
    fi
fi

# ── Step 8: Application URL Check ───────────────────────────────────────
step "8/9" "Checking application URL..."

APP_URL=$(grep "^APP_URL=" .env | cut -d'=' -f2)
info "Application URL: $APP_URL"

if command_exists curl; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/admin" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
        success "Application is responding (HTTP $HTTP_CODE)"
    else
        warn "Application returned HTTP $HTTP_CODE"
        info "The application may need additional configuration"
    fi
else
    info "curl not available, skipping URL check"
fi

# ── Step 9: Cleanup and Final Report ─────────────────────────────────────
step "9/9" "Finalizing restore..."

# Cleanup temp directory
rm -rf "$TEMP_DIR"
success "Temporary files cleaned up"

# Final report
echo ""
echo "════════════════════════════════════════════════════════════════"
success "RESTORE COMPLETE!"
echo "════════════════════════════════════════════════════════════════"
echo ""
info "Application URL: $APP_URL/admin"
info "Database: $DB_NAME ($TABLE_COUNT tables)"
echo ""
info "Next steps:"
echo "  1. Test admin login at $APP_URL/admin"
echo "  2. Verify projects and tickets are present"
echo "  3. Test queue worker: docker compose logs queue"
echo "  4. Configure email if needed (check .env)"
echo ""
info "Container management:"
echo "  docker compose ps              # Check status"
echo "  docker compose logs -f         # View logs"
echo "  docker compose restart app     # Restart app"
echo ""
echo "════════════════════════════════════════════════════════════════"
```

- [ ] **Step 2: Test full restore script**

```bash
# This is a full restore - make sure you have a backup of current state first!
# bash scripts/restore-migration.sh backups/project-management-*.tar.gz
```

Expected: Complete restore with verification

- [ ] **Step 3: Verify application**

```bash
# Check application
curl -I http://localhost:8000/admin
docker compose ps
```

Expected: Application should be running

- [ ] **Step 4: Commit**

```bash
git add scripts/restore-migration.sh
git commit -m "feat: complete restore script with verification and reporting"
```

---

## Task 18: Create Documentation

**Files:**
- Create: `/docs/migration-guide.md`

- [ ] **Step 1: Write comprehensive migration guide**

```markdown
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
   /backups/project-management-2025-06-13-103000.tar.gz
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

2. Follow the interactive prompts:
   - APP_KEY: Generate new or use backup
   - DB_PASSWORD: Set a secure password
   - APP_URL: Enter the new domain
   - CLOUDFLARE_TUNNEL_TOKEN: Enter your new token

3. Wait for restore to complete

4. Verify the restore:
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
