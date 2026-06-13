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

# Check required tools (host tools only, mysqldump runs inside container)
for tool in tar gzip sha256sum; do
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
    if ! docker exec "$DB_CONTAINER" mariadb-dump \
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

# ── Step 6: Generate Metadata ───────────────────────────────────────────
step "6/8" "Generating metadata..."

TOTAL_SIZE=$((DB_SIZE + STORAGE_SIZE))
BACKUP_DATE=$(date -Iseconds)
HOSTNAME=$(hostname)
APP_URL=$(grep "^APP_URL=" .env | cut -d'=' -f2)

if [ -f "$SCRIPT_DIR/templates/metadata.json.template" ]; then
    # Replace placeholders in template (use | delimiter to avoid issues with slashes)
    sed -e "s|{{BACKUP_DATE}}|$BACKUP_DATE|g" \
        -e "s|{{DB_NAME}}|$DB_NAME|g" \
        -e "s|{{DB_SIZE}}|$DB_SIZE|g" \
        -e "s|{{STORAGE_SIZE}}|$STORAGE_SIZE|g" \
        -e "s|{{TOTAL_SIZE}}|$TOTAL_SIZE|g" \
        -e "s|{{HOSTNAME}}|$HOSTNAME|g" \
        -e "s|{{APP_URL}}|$APP_URL|g" \
        -e "s|{{ARCHIVE_NAME}}|$BACKUP_NAME|g" \
        "$SCRIPT_DIR/templates/metadata.json.template" > "$METADATA_FILE"

    # Mark checksum for calculation after compression
    sed -i 's/"checksum": "",/"checksum": "sha256:CALCULATING",/' "$METADATA_FILE"

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
