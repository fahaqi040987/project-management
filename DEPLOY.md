# 🚀 Panduan Deploy ke VPS dengan Docker + Cloudflare Tunnel

## Arsitektur

```
Internet → Cloudflare (DNS + SSL) → cloudflared tunnel → nginx → php-fpm → MySQL
```

Tidak ada port yang perlu dibuka di firewall VPS. Semua traffic masuk lewat tunnel Cloudflare yang terenkripsi.

---

## Prasyarat

| Kebutuhan | Keterangan |
|-----------|------------|
| VPS | Ubuntu 22.04 / Debian 12 minimal |
| Docker + Docker Compose | Otomatis di-install oleh script |
| Domain | Sudah terdaftar & nameserver pointing ke Cloudflare |
| Akun Cloudflare | Free plan sudah cukup |
| Cloudflare Tunnel Token | Dari Zero Trust Dashboard (lihat Step 2 di bawah) |
| Git | Untuk clone repo |

---

## Quick Deploy (Script Otomatis)

Deploy lengkap dengan satu perintah:

```bash
git clone https://github.com/SeptiawanAjiP/dewakoding-project-management project-management
cd project-management
bash deploy.sh
```

Script akan otomatis:
1. Cek & install Docker, Node.js jika belum ada
2. Konfigurasi `.env` production (interaktif — akan menanyakan domain, password DB, dan Cloudflare Tunnel Token)
3. Build frontend assets (`npm install && npm run build`)
4. Build & jalankan **semua** container Docker: `app`, `queue`, `nginx`, `db`, `phpmyadmin`, **`cloudflared`**
5. Setup Laravel (Filament Shield + buat user admin)
6. Verifikasi deployment

### Opsi Script

| Flag | Keterangan |
|------|------------|
| `--skip-frontend` | Lewati npm install & build (untuk update tanpa perubahan frontend) |
| `--force-build` | Paksa rebuild frontend assets |
| `--help` | Tampilkan bantuan |

### Contoh Penggunaan

```bash
# Deploy pertama kali
bash deploy.sh

# Update aplikasi (tanpa rebuild frontend)
git pull
bash deploy.sh --skip-frontend

# Force rebuild frontend setelah git pull
git pull
bash deploy.sh --force-build
```

> **Catatan:** Script bersifat idempotent — aman dijalankan ulang. Jika `.env` sudah ada, script akan bertanya apakah ingin menggunakan yang lama atau membuat baru.

---

## Manual Deploy Steps

Jika ingin deploy secara manual, ikuti langkah-langkah berikut:

### Step 1 — Install Docker di VPS

```bash
# Login ke VPS via SSH
ssh user@your-vps-ip

# Install Docker (Ubuntu/Debian)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# Verifikasi
docker --version
docker compose version
```

---

### Step 2 — Buat Cloudflare Tunnel

### 2a. Buat Tunnel di Cloudflare Dashboard

1. Buka [https://one.dash.cloudflare.com](https://one.dash.cloudflare.com)
2. Pilih akun Anda → **Zero Trust** (menu kiri)
3. Klik **Networks** → **Tunnels**
4. Klik **+ Create a tunnel**
5. Pilih **Cloudflared** → klik **Next**
6. Beri nama tunnel, misal: `project-management-vps`
7. Pilih environment: **Docker**
8. **Copy token** yang ditampilkan (format panjang dimulai `eyJ...`)
9. Klik **Next**

### 2b. Konfigurasi Public Hostname

Masih di wizard pembuatan tunnel:

1. Klik tab **Public Hostname**
2. Klik **Add a public hostname**
3. Isi:
   - **Subdomain**: `pm` (atau kosongkan untuk domain utama)
   - **Domain**: pilih domain Anda
   - **Type**: `HTTP`
   - **URL**: `nginx:80`  ← nama service nginx di Docker internal
4. Klik **Save tunnel**

> **Hasil**: akses `https://pm.yourdomain.com` akan masuk ke nginx container Anda.

---

### Step 3 — Clone Repo di VPS

```bash
# Di VPS
cd /opt  # atau direktori pilihan Anda
git clone https://github.com/SeptiawanAjiP/dewakoding-project-management project-management
cd project-management
```

---

### Step 4 — Konfigurasi Environment

```bash
# Salin template .env production
cp .env.production.example .env

# Edit file .env
nano .env
```

**Minimal yang HARUS diubah di .env:**

```env
APP_URL=https://pm.yourdomain.com      # Domain Cloudflare Anda
APP_KEY=                               # Akan di-generate di bawah
DB_PASSWORD=GANTI_PASSWORD_KUAT        # Password MySQL
CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoiXXX   # Token dari Step 2a
```

---

### Step 5 — Build & Jalankan

```bash
# Build frontend assets (wajib dilakukan sekali sebelum docker up)
npm install
npm run build

# Build Docker image
docker compose build

# Generate APP_KEY
docker compose run --rm app php artisan key:generate --show
# Salin hasilnya ke .env → APP_KEY=base64:xxx...

# Jalankan semua service di background
docker compose up -d

# Cek status
docker compose ps
```

**Output yang diharapkan:**
```
NAME                   STATUS
laravel_app            running
laravel_nginx          running
laravel_db             running (healthy)
laravel_queue          running
laravel_cloudflared    running
laravel_phpmyadmin     running
```

---

### Step 6 — Setup Awal Laravel

```bash
# Cek log bootstrap (migrate, cache, dll)
docker compose logs app

# Setup Filament Shield (RBAC)
docker compose exec app php artisan shield:setup
docker compose exec app php artisan shield:install
docker compose exec app php artisan shield:super-admin

# Buat user admin pertama
docker compose exec app php artisan make:filament-user
```

---

### Step 7 — Verifikasi

Buka browser → `https://pm.yourdomain.com/admin`

Pastikan:
- [ ] Halaman login muncul (bukan error 502/504)
- [ ] Login berhasil
- [ ] Dashboard menampilkan data
- [ ] SSL aktif (gembok hijau) — ditangani Cloudflare otomatis

---

## Akses phpMyAdmin (Opsional)

phpMyAdmin hanya bisa diakses via SSH tunnel (tidak expose ke internet):

```bash
# Di komputer lokal Anda
ssh -L 8080:localhost:8080 user@your-vps-ip

# Buka di browser lokal
# http://localhost:8080
```

---

## Perintah Berguna

```bash
# Lihat log semua service
docker compose logs -f

# Lihat log service tertentu
docker compose logs -f app
docker compose logs -f cloudflared

# Restart service
docker compose restart app

# Stop semua
docker compose down

# Update aplikasi (setelah git pull)
git pull
npm run build
docker compose build app
docker compose up -d --no-deps app queue
# Migrasi dijalankan otomatis oleh entrypoint.sh

# Masuk ke shell container
docker compose exec app bash
docker compose exec db mysql -u root -p
```

---

## Update Aplikasi

```bash
# Di VPS
cd /opt/project-management

git pull origin main

# Cara cepat (menggunakan deploy script):
bash deploy.sh --skip-frontend
# Atau jika ada perubahan frontend:
bash deploy.sh --force-build

# Atau manual:
npm install && npm run build
docker compose build app queue
docker compose up -d --no-deps --build app queue

# Migrasi, cache clear, dsb. dijalankan otomatis oleh entrypoint.sh
```

---

## Troubleshooting

| Problem | Kemungkinan Penyebab | Solusi |
|---------|---------------------|--------|
| 502 Bad Gateway | php-fpm belum siap | `docker compose logs app` — tunggu bootstrap selesai |
| Tunnel disconnected | Token salah / expired | Cek `docker compose logs cloudflared`, generate token baru |
| Asset URL masih `http://` | `APP_URL` salah | Pastikan `APP_URL=https://yourdomain.com` di `.env` |
| Login redirect loop | Session/cookie issue | Cek `SESSION_DOMAIN` dan `APP_URL` di `.env` |
| DB connection refused | `DB_HOST` salah | Harus `DB_HOST=db` (nama service docker) bukan `127.0.0.1` |
| Email tidak terkirim | Queue worker mati | `docker compose restart queue` |
| Permission denied di storage | Mount volume salah | `docker compose exec app chown -R www-data:www-data storage` |

---

## Keamanan Tambahan (Rekomendasi)

```bash
# Di VPS: pastikan firewall aktif dan hanya allow SSH
sudo ufw allow ssh
sudo ufw enable
sudo ufw status

# Port 80/443 TIDAK perlu dibuka karena traffic lewat Cloudflare Tunnel
# Port 3306 (MySQL) TIDAK diekspos ke host
# Port 8080 (phpMyAdmin) hanya bind ke 127.0.0.1
```

Di Cloudflare Dashboard, aktifkan:
- **WAF** (Web Application Firewall) — proteksi serangan
- **Bot Fight Mode** — blokir bot
- **Always Use HTTPS** — paksa redirect HTTP → HTTPS
