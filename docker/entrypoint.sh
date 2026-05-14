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

# Cache config, route, dan view untuk performance
echo "==> [entrypoint] Optimizing application..."
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache

echo "==> [entrypoint] Bootstrap complete. Starting PHP-FPM..."

# Jalankan php-fpm
exec php-fpm
