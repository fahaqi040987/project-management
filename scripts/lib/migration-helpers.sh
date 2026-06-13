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
