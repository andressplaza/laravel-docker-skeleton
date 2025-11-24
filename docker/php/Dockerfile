# ================================
# STAGE 1: BUILDER - Resolver dependencias con composer
# ================================
FROM php:8.3-fpm as builder

# Instalar herramientas de construcción
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libzip-dev \
    libpq-dev \
    libcurl4-openssl-dev \
    && docker-php-ext-install \
        pdo_pgsql \
        zip \
        mbstring \
        bcmath \
        curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copiar composer
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# Copiar archivos de composer
WORKDIR /build
COPY src/composer.json src/composer.lock* ./

# Instalar dependencias sin dev (para producción)
ARG ENV=development
RUN if [ "$ENV" = "production" ]; then \
        composer install --no-dev --no-interaction --no-progress --prefer-dist --optimize-autoloader; \
    else \
        composer install --no-interaction --no-progress --prefer-dist; \
    fi

# ================================
# STAGE 2: RUNTIME - Imagen final optimizada
# ================================
FROM php:8.3-fpm

ARG ENV=development

LABEL maintainer="Laravel Docker Skeleton"
LABEL environment="${ENV}"

# Instalar extensiones PHP necesarias (solo runtime)
RUN apt-get update && apt-get install -y \
    libpq5 \
    libonig4 \
    && docker-php-ext-install \
        pdo_pgsql \
        pgsql \
        mbstring \
        bcmath \
        ctype \
        fileinfo \
        opcache \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ================================
# Configuración PHP según entorno
# ================================
COPY docker/php/custom.${ENV}.ini /usr/local/etc/php/conf.d/custom.ini

# Configuración OPCache en producción
RUN if [ "$ENV" = "production" ]; then \
        echo "opcache.enable_cli=0" >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini; \
    fi

# ================================
# Usuario no-root por seguridad
# ================================
RUN groupadd -g 1000 laravel \
    && useradd -m -u 1000 -g laravel laravel

# ================================
# Directorio de trabajo
# ================================
WORKDIR /var/www/html

# Crear directorios con permisos correctos
RUN mkdir -p storage/logs storage/app storage/framework/cache storage/framework/sessions \
    && chown -R laravel:laravel /var/www/html

# ================================
# Copiar dependencias del builder
# ================================
COPY --from=builder --chown=laravel:laravel /build/vendor ./vendor

# ================================
# Copiar código de la aplicación
# ================================
COPY --chown=laravel:laravel src/ ./

# ================================
# Cambiar a usuario no-root
# ================================
USER laravel

# ================================
# Health check
# ================================
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD php -f /var/www/html/artisan schedule:work || exit 1

# ================================
# Comando por defecto
# ================================
CMD ["php-fpm"]
