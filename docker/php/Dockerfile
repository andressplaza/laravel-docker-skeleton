# Dockerfile PHP

FROM php:8.3-fpm

# Extensiones necesarias
RUN apt-get update && apt-get install -y \
    git unzip libzip-dev libpng-dev libonig-dev curl libpq-dev \
    && docker-php-ext-install pdo_pgsql zip \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Crear usuario laravel
RUN groupadd -g 1000 laravel \
    && useradd -m -u 1000 -g laravel laravel \
    && mkdir -p /var/www/html \
    && chown -R laravel:laravel /var/www/html

# Copiar php.ini
COPY php.ini /usr/local/etc/php/php.ini

# Cambiar a usuario no root
USER laravel
WORKDIR /var/www/html

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

CMD ["php-fpm"]

