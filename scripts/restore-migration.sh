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
            echo "  --help, -h        Show this help"
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

# Extract just metadata.json (try both with and without ./ prefix)
if ! tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR" ./metadata.json 2>/dev/null; then
    if ! tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR" metadata.json 2>/dev/null; then
        warn "Could not extract metadata.json (may be old backup format)"
        METADATA_VALID=false
    else
        METADATA_VALID=true
    fi
else
    METADATA_VALID=true
fi

if [ "$METADATA_VALID" = "true" ]; then
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

# Show checksum for user reference
ACTUAL_CHECKSUM=$(sha256sum "$BACKUP_FILE" | cut -d' ' -f1)
info "Archive checksum: sha256:$ACTUAL_CHECKSUM"

success "Backup file validated"

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

# For restore script, skip interactive prompts
# User will need to edit .env manually for sensitive values
info "Remember to update sensitive values in .env:"
info "  - APP_KEY (generate with: php artisan key:generate)"
info "  - DB_PASSWORD"
info "  - CLOUDFLARE_TUNNEL_TOKEN"

success "Environment configuration complete"

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
        info "Setting storage permissions..."
        chown -R www-data:www-data "$STORAGE_TARGET" 2>/dev/null || \
            warn "Could not set ownership (may need manual: sudo chown -R www-data:www-data storage)"

        chmod -R 775 "$STORAGE_TARGET" 2>/dev/null || true

        STORAGE_SIZE=$(du -sb "$STORAGE_TARGET" 2>/dev/null | cut -f1)
        success "Storage files restored: $(format_bytes $STORAGE_SIZE)"
    fi
else
    warn "Skipping storage restore (--skip-storage)"
fi

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
if [ "$SKIP_DATABASE" = "false" ]; then
    info "Database: $DB_NAME ($TABLE_COUNT tables)"
fi
echo ""
info "Next steps:"
echo "  1. Update sensitive values in .env (APP_KEY, DB_PASSWORD, etc)"
echo "  2. Test admin login at $APP_URL/admin"
echo "  3. Verify projects and tickets are present"
echo "  4. Restart containers: docker compose restart"
echo ""
info "Container management:"
echo "  docker compose ps              # Check status"
echo "  docker compose logs -f         # View logs"
echo "  docker compose restart app     # Restart app"
echo ""
echo "════════════════════════════════════════════════════════════════"
