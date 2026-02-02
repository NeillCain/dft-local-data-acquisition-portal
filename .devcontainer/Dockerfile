FROM mcr.microsoft.com/devcontainers/php:8.3-bookworm

# System/build deps incl. GD + GMP + MySQL client headers
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libicu-dev libzip-dev zlib1g-dev libxml2-dev libonig-dev pkg-config \
        libpng-dev libjpeg-dev libwebp-dev libfreetype6-dev \
        libgmp-dev default-mysql-client git unzip entr; \
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp; \
    docker-php-ext-install -j"$(nproc)" intl zip mbstring xml opcache gd gmp pdo_mysql; \
    rm -rf /var/lib/apt/lists/*
