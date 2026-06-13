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
