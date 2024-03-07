FROM php:8.2-fpm AS app

# docker run php:7.4-fpm php -m
# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
	curl \
	libpng-dev \
	libonig-dev \
	libxml2-dev \
	libmcrypt-dev \
	libicu-dev \
	libzip-dev \
	zip \
	unzip \
	&& apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# Install PHP extensions
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd \
	&& docker-php-ext-configure intl \
	&& docker-php-ext-install intl zip

# Install imagick
RUN apt-get update && apt-get install -y --no-install-recommends \
	libmagickwand-dev \
	&& pecl install imagick \
	&& docker-php-ext-enable imagick \
	&& apt-get clean && rm -rf /var/lib/apt/lists/*

# Get latest Composer
COPY --from=composer:2.2 /usr/bin/composer /usr/bin/composer

# PHP.ini configs
COPY ./w2z-docker/php.ini /usr/local/etc/php/conf.d/app.ini

# Create project folder
RUN mkdir -p /var/www



###############################################################################
FROM app AS dev

# Add local user id to www-data user
RUN usermod -u 1000 www-data && groupmod -g 1000 www-data \
	&& chown -R www-data:www-data /var/www \
	&& chmod -R ug+w /var/www \
	&& cp "$PHP_INI_DIR"/php.ini-development "$PHP_INI_DIR"/php.ini

EXPOSE 9000



###############################################################################
FROM app AS prod


# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
	nginx \
	supervisor \
	&& apt-get clean && rm -rf /var/lib/apt/lists/* \
	&& rm -rf /etc/nginx/sites-enabled/*

# Copy Nginx/supervisor configs
COPY ./w2z-docker/nginx/prod.conf /etc/nginx/conf.d/default.conf
COPY ./w2z-docker/supervisord.conf /etc/supervisord.conf
COPY ./w2z-docker/entrypoint.sh /etc/entrypoint.sh

# Copy source to container
COPY --chown=www-data:www-data . /var/www

# Deployment steps
WORKDIR /var/www

# Set user and permissions
RUN chown -R www-data:www-data /var/www \
	&& chmod -R ug+w /var/www/storage \
	&& composer install --optimize-autoloader --no-dev \
	&& chmod +x /etc/entrypoint.sh

EXPOSE 80
ENTRYPOINT ["sh", "/etc/entrypoint.sh"]



###############################################################################
FROM nginx:1.21.3-alpine AS nginx

RUN apk add --no-cache bash \
	&& rm -rf /var/cache/apk/* \
	&& mkdir -p /var/www

COPY ./w2z-docker/nginx/app.conf /etc/nginx/conf.d/default.conf
