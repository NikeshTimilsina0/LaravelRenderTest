# Stage 1: Build assets and install composer dependencies
FROM php:8.3-cli-alpine AS builder

# Install system dependencies & PHP extension build dependencies
RUN apk add --no-no-cache \
    curl \
    git \
    unzip \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    icu-dev \
    oniguruma-dev \
    nodejs \
    npm

# Install PHP extensions required by Laravel
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo_mysql mbstring gd zip bcmath intl opcache

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /app

# Copy dependency definition files first (leverage layer caching)
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist

# Copy package files and build frontend assets
COPY package.json package-lock.json* vite.config.js* ./
RUN if [ -f package.json ]; then npm ci && npm run build; fi

# Copy full application code
COPY . .

# Autoload optimization
RUN composer dump-autoload --optimize


# Stage 2: Production runtime image
FROM php:8.3-fpm-alpine

# Install production system dependencies
RUN apk add --no-cache \
    nginx \
    supervisor \
    curl \
    libpng \
    libjpeg-turbo \
    freetype \
    libzip \
    icu-libs \
    oniguruma

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo_mysql mbstring gd zip bcmath intl opcache

# Configure PHP for production
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

WORKDIR /var/www/html

# Copy application and built assets from builder stage
COPY --from=builder /app /var/www/html

# Set directory permissions for Laravel
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Copy Nginx and Supervisor configurations
COPY docker/nginx.conf /etc/nginx/http.d/default.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose Render's default port
EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]