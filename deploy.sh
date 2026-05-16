#!/usr/bin/env bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════════════════════
# DewaKoding Project Management — Automated Deployment Script
# Deploy ke VPS dengan Docker + Cloudflare Tunnel
# ══════════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
CURRENT_STEP="init"

# ── Color Helpers ──────────────────────────────────────────────────────────────
info()    { printf "\033[1;34m[INFO]\033[0m  %s\n" "$1"; }
success() { printf "\033[1;32m[OK]\033[0m    %s\n" "$1"; }
warn()    { printf "\033[1;33m[WARN]\033[0m  %s\n" "$1"; }
error()   { printf "\033[1;31m[ERROR]\033[0m %s\n" "$1" >&2; }
step()    { printf "\n\033[1;36m[%s]\033[0m %s\n" "$1" "$2"; }
die()     { error "$1"; exit 1; }

# ── Error Trap ─────────────────────────────────────────────────────────────────
trap 'error "Deployment gagal di step: $CURRENT_STEP"' ERR

# ── Parse Flags ────────────────────────────────────────────────────────────────
SKIP_FRONTEND=false
FORCE_BUILD=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --skip-frontend) SKIP_FRONTEND=true ;;
        --force-build)   FORCE_BUILD=true ;;
        --help|-h)
            echo "Usage: bash deploy.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-frontend   Skip npm install & build"
            echo "  --force-build     Force rebuild frontend assets"
            echo "  --help, -h        Show this help"
            exit 0
            ;;
        *) warn "Flag tidak dikenali: $1" ;;
    esac
    shift
done

# ── Helper: Prompt with default ────────────────────────────────────────────────
prompt() {
    local varname="$1" label="$2" default="${3:-}"
    if [[ -n "$default" ]]; then
        printf "  %s [%s]: " "$label" "$default"
    else
        printf "  %s: " "$label"
    fi
    read -r value
    value="${value:-$default}"
    if [[ -z "$value" ]]; then
        die "$label tidak boleh kosong."
    fi
    printf -v "$varname" '%s' "$value"
}

# ── Helper: Check command exists ───────────────────────────────────────────────
need_cmd() {
    if ! command -v "$1" &>/dev/null; then
        return 1
    fi
    return 0
}

# ── Helper: Update .env value ──────────────────────────────────────────────────
env_set() {
    local key="$1" value="$2"
    if grep -q "^${key}=" .env 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" .env
    else
        echo "${key}=${value}" >> .env
    fi
}

env_get() {
    grep "^${1}=" .env 2>/dev/null | head -1 | cut -d'=' -f2-
}

# ══════════════════════════════════════════════════════════════════════════════
# Step 1: Check Prerequisites
# ══════════════════════════════════════════════════════════════════════════════
check_prerequisites() {
    CURRENT_STEP="prerequisites"
    step "1/6" "Cek prerequisites..."

    # OS check
    if [[ "$(uname -s)" != "Linux" ]]; then
        warn "Script ini dirancang untuk Linux (VPS). OS Anda: $(uname -s)"
        warn "Lanjutkan dengan risiko sendiri."
        read -r -p "  Lanjutkan? [y/N]: " confirm
        [[ "${confirm:-}" =~ ^[Yy]$ ]] || exit 0
    fi

    # Docker
    if ! need_cmd docker; then
        warn "Docker belum terinstall."
        read -r -p "  Install Docker sekarang? [Y/n]: " install_docker
        if [[ "${install_docker:-Y}" =~ ^[Yy]$ ]]; then
            info "Installing Docker..."
            curl -fsSL https://get.docker.com | sh
            sudo usermod -aG docker "$USER"
            success "Docker terinstall. Jalankan 'newgrp docker' atau logout/login."
            info "Lalu jalankan ulang: bash deploy.sh"
            exit 0
        else
            die "Docker diperlukan. Install manual: https://docs.docker.com/engine/install/"
        fi
    fi
    success "Docker: $(docker --version)"

    # Docker Compose v2
    if ! docker compose version &>/dev/null; then
        die "Docker Compose v2 tidak ditemukan. Update Docker: curl -fsSL https://get.docker.com | sh"
    fi
    success "Docker Compose: $(docker compose version --short)"

    # Docker permissions
    if ! docker info &>/dev/null 2>&1; then
        die "Tidak bisa akses Docker. Tambahkan user ke docker group: sudo usermod -aG docker \$USER && newgrp docker"
    fi

    # git & curl
    need_cmd git  || die "git belum terinstall. Install: sudo apt install -y git"
    need_cmd curl || die "curl belum terinstall. Install: sudo apt install -y curl"
    success "git & curl: OK"

    # Node.js / npm (needed for frontend build)
    if [[ "$SKIP_FRONTEND" == "false" ]]; then
        if ! need_cmd node || ! need_cmd npm; then
            warn "Node.js/npm belum terinstall (diperlukan untuk build frontend)."
            read -r -p "  Install Node.js 22.x LTS sekarang? [Y/n]: " install_node
            if [[ "${install_node:-Y}" =~ ^[Yy]$ ]]; then
                info "Installing Node.js 22.x LTS..."
                curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
                sudo apt-get install -y nodejs
                success "Node.js: $(node --version)"
                success "npm: $(npm --version)"
            else
                warn "Tanpa Node.js, frontend TIDAK akan di-build."
                warn "Gunakan flag --skip-frontend jika build sudah dilakukan di CI."
                read -r -p "  Lanjutkan tanpa build frontend? [y/N]: " skip_fe
                if [[ "${skip_fe:-}" =~ ^[Yy]$ ]]; then
                    SKIP_FRONTEND=true
                else
                    die "Install Node.js manual: https://nodejs.org/en/download"
                fi
            fi
        else
            success "Node.js: $(node --version), npm: $(npm --version)"
        fi
    fi

    # Verify required files exist
    [[ -f "docker-compose.yml" ]]     || die "docker-compose.yml tidak ditemukan."
    [[ -f "Dockerfile" ]]             || die "Dockerfile tidak ditemukan."
    [[ -f ".env.production.example" ]] || die ".env.production.example tidak ditemukan."
    success "File konfigurasi: OK"
}

# ══════════════════════════════════════════════════════════════════════════════
# Step 2: Setup Environment
# ══════════════════════════════════════════════════════════════════════════════
setup_environment() {
    CURRENT_STEP="environment"
    step "2/6" "Konfigurasi environment..."

    if [[ -f ".env" ]]; then
        existing_url="$(env_get APP_URL)"
        existing_key="$(env_get APP_KEY)"
        if [[ -n "$existing_key" && "$existing_key" != "" && "$existing_key" != "base64:"* ]]; then
            true # key is set
        fi

        warn "File .env sudah ada."
        read -r -p "  Gunakan .env yang ada? [Y/n]: " use_existing
        if [[ "${use_existing:-Y}" =~ ^[Yy]$ ]]; then
            success "Menggunakan .env yang sudah ada."

            # Check critical values
            if [[ -z "$(env_get APP_URL)" ]]; then
                prompt APP_URL "Masukkan APP_URL (contoh: https://pm.yourdomain.com)"
                env_set APP_URL "$APP_URL"
            fi
            if [[ -z "$(env_get DB_PASSWORD)" || "$(env_get DB_PASSWORD)" == "GANTI_PASSWORD_KUAT_DISINI" ]]; then
                prompt DB_PASSWORD "Masukkan DB_PASSWORD"
                env_set DB_PASSWORD "$DB_PASSWORD"
            fi
            if [[ -z "$(env_get CLOUDFLARE_TUNNEL_TOKEN)" || "$(env_get CLOUDFLARE_TUNNEL_TOKEN)" == *"XXX"* ]]; then
                prompt CLOUDFLARE_TUNNEL_TOKEN "Masukkan Cloudflare Tunnel Token (eyJ...)"
                env_set CLOUDFLARE_TUNNEL_TOKEN "$CLOUDFLARE_TUNNEL_TOKEN"
            fi
            return 0
        fi

        # Backup existing .env
        cp .env ".env.backup.$(date +%Y%m%d%H%M%S)"
        info "Backup .env lama dibuat."
    fi

    # Copy production template
    cp .env.production.example .env
    success ".env dibuat dari .env.production.example"

    # Interactive prompts
    echo ""
    info "Konfigurasi aplikasi:"
    echo ""

    prompt APP_URL "Masukkan APP_URL (contoh: https://pm.yourdomain.com)"
    env_set APP_URL "$APP_URL"

    local default_db_pass
    default_db_pass="$(openssl rand -base64 24 | tr -d '=/+' | head -c 32)"
    prompt DB_PASSWORD "Masukkan DB_PASSWORD (kosongkan untuk auto-generate)" "$default_db_pass"
    env_set DB_PASSWORD "$DB_PASSWORD"

    prompt CLOUDFLARE_TUNNEL_TOKEN "Masukkan Cloudflare Tunnel Token (eyJ...)"
    if [[ ! "$CLOUDFLARE_TUNNEL_TOKEN" == eyJ* ]]; then
        warn "Token tidak dimulai dengan 'eyJ' — pastikan token Cloudflare Tunnel benar."
        read -r -p "  Lanjutkan? [y/N]: " confirm_token
        [[ "${confirm_token:-}" =~ ^[Yy]$ ]] || die "Token dibatalkan."
    fi
    env_set CLOUDFLARE_TUNNEL_TOKEN "$CLOUDFLARE_TUNNEL_TOKEN"

    success "Environment configured."
    info "  APP_URL: $APP_URL"
    info "  DB_PASSWORD: ********"
    info "  TUNNEL_TOKEN: ${CLOUDFLARE_TUNNEL_TOKEN:0:10}..."
}

# ══════════════════════════════════════════════════════════════════════════════
# Step 3: Build Frontend
# ══════════════════════════════════════════════════════════════════════════════
build_frontend() {
    CURRENT_STEP="frontend"
    step "3/6" "Build frontend assets..."

    if [[ "$SKIP_FRONTEND" == "true" ]]; then
        warn "Skip frontend build (--skip-frontend)."
        return 0
    fi

    # Idempotency: skip if already built unless --force-build
    if [[ -f "public/build/.vite/manifest.json" ]] && [[ "$FORCE_BUILD" == "false" ]]; then
        success "Frontend assets sudah ada. Gunakan --force-build untuk rebuild."
        return 0
    fi

    info "Installing npm dependencies..."
    npm install

    info "Building frontend assets..."
    npm run build

    if [[ -f "public/build/.vite/manifest.json" ]]; then
        success "Frontend assets berhasil di-build."
    else
        warn "manifest.json tidak ditemukan di public/build/. Vite build mungkin gagal."
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# Step 4: Build & Start Docker Services (termasuk cloudflared)
# ══════════════════════════════════════════════════════════════════════════════
docker_build_and_start() {
    CURRENT_STEP="docker"
    step "4/6" "Build & jalankan Docker services..."

    # Build images
    info "Building Docker images..."
    docker compose build

    # Generate APP_KEY if not already set
    local existing_key
    existing_key="$(env_get APP_KEY)"
    if [[ -z "$existing_key" ]]; then
        info "Generating APP_KEY..."
        local generated_key
        generated_key="$(docker compose run --rm app php artisan key:generate --show)"
        env_set APP_KEY "$generated_key"
        success "APP_KEY: ${generated_key:0:20}..."
    else
        success "APP_KEY sudah ada, skip generate."
    fi

    # Start all services (app, queue, nginx, db, phpmyadmin, cloudflared)
    info "Starting semua services..."
    docker compose up -d

    # Wait for database to be healthy
    info "Menunggu database healthy..."
    local retries=0
    local max_retries=24  # 24 x 5s = 120s
    while [[ $retries -lt $max_retries ]]; do
        if docker compose ps db --format json 2>/dev/null | grep -q '"healthy"' 2>/dev/null; then
            break
        fi
        retries=$((retries + 1))
        printf "  Waiting for db... (%ds/%ds)\r" "$((retries * 5))" "$((max_retries * 5))"
        sleep 5
    done

    if [[ $retries -eq $max_retries ]]; then
        die "Database tidak healthy setelah 120s. Cek: docker compose logs db"
    fi
    success "Database: healthy"

    # Wait for app container to finish entrypoint bootstrap
    info "Menunggu app bootstrap selesai..."
    local app_retries=0
    local app_max_retries=30  # 30 x 4s = 120s
    while [[ $app_retries -lt $app_max_retries ]]; do
        if docker compose logs app 2>/dev/null | grep -q "Bootstrap complete"; then
            break
        fi
        app_retries=$((app_retries + 1))
        sleep 4
    done

    if [[ $app_retries -eq $app_max_retries ]]; then
        warn "App bootstrap mungkin belum selesai. Cek: docker compose logs app"
    else
        success "App bootstrap: complete"
    fi

    success "Semua services dijalankan."
}

# ══════════════════════════════════════════════════════════════════════════════
# Step 5: Setup Laravel
# ══════════════════════════════════════════════════════════════════════════════
setup_laravel() {
    CURRENT_STEP="laravel"
    step "5/6" "Setup Laravel..."

    # Shield setup (role-based access control)
    info "Installing Filament Shield..."
    docker compose exec -T app php artisan shield:install --yes 2>/dev/null || \
        warn "Shield install sudah pernah dijalankan atau gagal. Cek manual jika perlu."

    info "Generating super-admin role..."
    docker compose exec -T app php artisan shield:super-admin 2>/dev/null || \
        warn "Super-admin role sudah ada atau gagal."

    # Create admin user
    echo ""
    info "Buat user admin pertama:"
    echo ""

    read -r -p "  Nama [Admin]: " admin_name
    admin_name="${admin_name:-Admin}"

    read -r -p "  Email [admin@example.com]: " admin_email
    admin_email="${admin_email:-admin@example.com}"

    read -r -p "  Password [auto-generate]: " admin_password
    if [[ -z "$admin_password" ]]; then
        admin_password="$(openssl rand -base64 16 | tr -d '=/+' | head -c 16)"
    fi

    info "Membuat user admin..."
    if printf "%s\n%s\n%s\n" "$admin_name" "$admin_email" "$admin_password" | \
       docker compose exec -T app php artisan make:filament-user 2>/dev/null; then
        success "User admin berhasil dibuat."
        info "  Email:    $admin_email"
        info "  Password: $admin_password"
        warn "SIMPAN PASSWORD INI!"
    else
        warn "Gagal membuat user secara otomatis."
        info "Jalankan manual:"
        info "  docker compose exec app php artisan make:filament-user"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# Step 6: Verify Deployment
# ══════════════════════════════════════════════════════════════════════════════
verify_deployment() {
    CURRENT_STEP="verify"
    step "6/6" "Verifikasi deployment..."

    echo ""
    info "Status container:"
    docker compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null || docker compose ps

    echo ""
    info "Cloudflare Tunnel logs (terakhir):"
    docker compose logs cloudflared --tail 10 2>/dev/null

    local app_url
    app_url="$(env_get APP_URL)"

    echo ""
    echo "════════════════════════════════════════════════════════════════"
    success "DEPLOYMENT SELESAI!"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    info "Buka di browser: ${app_url}/admin"
    echo ""
    info "phpMyAdmin (via SSH tunnel dari lokal):"
    info "  ssh -L 8080:localhost:8080 user@vps-ip"
    info "  Lalu buka: http://localhost:8080"
    echo ""
    info "Perintah berguna:"
    info "  docker compose logs -f            # Lihat semua logs"
    info "  docker compose logs -f cloudflared # Lihat tunnel logs"
    info "  docker compose exec app bash       # Masuk container app"
    echo ""
    info "Update aplikasi:"
    info "  git pull && npm run build"
    info "  docker compose build app queue"
    info "  docker compose up -d --no-deps --build app queue"
    info "  # Atau: bash deploy.sh --skip-frontend"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
}

# ══════════════════════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════════════════════
main() {
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  DewaKoding Project Management — Deployment Script"
    echo "  Docker + Cloudflare Tunnel"
    echo "════════════════════════════════════════════════════════════════"
    echo ""

    check_prerequisites
    setup_environment
    build_frontend
    docker_build_and_start
    setup_laravel
    verify_deployment
}

main "$@"
