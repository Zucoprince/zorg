#!/usr/bin/env sh
set -e

cd /var/www
php artisan cache:clear
php artisan optimize:clear
php artisan route:cache
php artisan queue:restart

# Inicia PHP/nginx/Laravel queue
/usr/bin/supervisord -c /etc/supervisord.conf
