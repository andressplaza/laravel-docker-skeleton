FROM php:8.3-fpm

ARG ENV=development

# -----------------------------
# Dependencias de sistema y PHP
# -----------------------------
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libzip-dev \
    libpng-dev \
    libonig-dev \
    libpq-dev \
    libcurl4-openssl-dev \
    curl \
    gnupg \
    build-essential \
    && docker-php-ext-install \
        pdo_pgsql \
        pgsql \
        zip \
        mbstring \
        bcmath \
        curl \
        fileinfo \
        ctype \
        opcache \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# -----------------------------
# Instalar Node.js y npm
# -----------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && node -v \
    && npm -v

# -----------------------------
# Crear usuario laravel
# -----------------------------
RUN groupadd -g 1000 laravel \
    && useradd -m -u 1000 -g laravel laravel \
    && mkdir -p /var/www/html \
    && chown -R laravel:laravel /var/www/html

# -----------------------------
# Copiar php.ini personalizado
# -----------------------------
COPY custom.${ENV}.ini /usr/local/etc/php/conf.d/custom.ini

# -----------------------------
# Cambiar a usuario no root
# -----------------------------
USER laravel
WORKDIR /var/www/html

# -----------------------------
# Composer
# -----------------------------
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# -----------------------------
# Comando por defecto
# -----------------------------
CMD ["php-fpm"]
