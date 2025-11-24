# Build stage
FROM php:8.2-fpm-alpine AS base

# Install system dependencies
RUN apk add --no-cache \
    git \
    curl \
    libpng-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    freetype-dev \
    libzip-dev \
    oniguruma-dev \
    icu-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        mysqli \
        mbstring \
        zip \
        exif \
        pcntl \
        bcmath \
        gd \
        intl

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Development stage
FROM base AS development

# Install Xdebug for development
RUN apk add --no-cache $PHPIZE_DEPS \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug

# Copy development php.ini
COPY ./docker/php/php.dev.ini /usr/local/etc/php/php.ini

# Production stage
FROM base AS production

# Copy production php.ini
COPY ./docker/php/php.prod.ini /usr/local/etc/php/php.ini

# Create a composer.json file if it doesn't exist (will be overridden by volume mount)
RUN echo '{"require": {}}' > /var/www/html/composer.json

# Set permissions for the working directory
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

USER www-data

EXPOSE 9000
