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
