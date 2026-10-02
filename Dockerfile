FROM php:8.4-apache

# System dependencies and PHP extensions Laravel needs
RUN apt-get update && apt-get install -y \
    git unzip curl libzip-dev libpng-dev libonig-dev libxml2-dev libsqlite3-dev \
    && docker-php-ext-install pdo pdo_mysql pdo_sqlite mbstring zip bcmath gd \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

# Node.js (for building Vite assets)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Serve from Laravel's public directory
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html
COPY . .

# Create required folders, then install PHP dependencies (scripts skipped; run at startup)
RUN mkdir -p bootstrap/cache \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views \
    storage/logs \
    && composer install --no-dev --optimize-autoloader --no-interaction --no-scripts

# Build frontend assets, then remove node_modules
RUN npm install && npm run build && rm -rf node_modules
# SQLite database file + permissions
RUN touch database/database.sqlite \
    && chown -R www-data:www-data storage bootstrap/cache database \
    && chmod -R 775 storage bootstrap/cache database

# Render provides a PORT env var; Apache must listen on it
CMD sed -i "s/80/${PORT:-10000}/g" /etc/apache2/ports.conf /etc/apache2/sites-available/000-default.conf \
    && php artisan package:discover --ansi \
    && php artisan migrate --force \
    && php artisan config:cache \
    && php artisan route:cache \
    && apache2-foreground