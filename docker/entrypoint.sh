#!/bin/bash
set -e

echo "==> [entrypoint] Starting Laravel bootstrap..."

# Tunggu database siap (sudah ditangani oleh healthcheck depends_on di compose)
echo "==> [entrypoint] Database is ready."

# Pastikan direktori storage & cache bisa ditulis
chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache
chmod -R 775 /var/www/storage /var/www/bootstrap/cache

# Install composer dependencies jika vendor belum ada
if [ ! -d "/var/www/vendor" ]; then
    echo "==> [entrypoint] Installing Composer dependencies..."
    composer install --no-dev --optimize-autoloader --no-interaction
fi

# Publish Filament assets agar Blade components tersedia
echo "==> [entrypoint] Publishing Filament assets..."
php artisan vendor:publish --tag=filament-assets --ansi --force 2>/dev/null || true
php artisan filament:upgrade 2>/dev/null || true

# Build frontend assets jika belum ada (opsional — lebih baik di-build sebelum deploy)
# npm run build

# Jalankan migrasi (--force agar bisa berjalan di production env)
echo "==> [entrypoint] Running migrations..."
php artisan migrate --force

# Buat storage symlink jika belum ada
if [ ! -L "/var/www/public/storage" ]; then
    echo "==> [entrypoint] Creating storage symlink..."
    php artisan storage:link
fi

# Cache config dan route untuk performance
# Note: view:cache dilewati karena Filament mendaftarkan Blade components
# secara dinamis yang bisa gagal di-compile saat cache build
echo "==> [entrypoint] Optimizing application..."
php artisan config:cache
php artisan route:cache
php artisan event:cache

echo "==> [entrypoint] Bootstrap complete. Starting PHP-FPM..."

# Jalankan php-fpm
exec php-fpm
