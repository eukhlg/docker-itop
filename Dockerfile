
ARG IMAGE_TAG=3.1.1
ARG BASE_VER=8.1-apache
ARG ITOP_DOWNLOAD_URL=https://sourceforge.net/projects/itop/files/itop/3.1.1-1/iTop-3.1.1-1-12561.zip/download
ARG DEBIAN_FRONTEND=noninteractive
ARG ITOP_TMP=/tmp/itop

FROM php:${BASE_VER} AS builder

ARG ITOP_TMP
ARG ITOP_DOWNLOAD_URL
ARG DEBIAN_FRONTEND

RUN ARCH=$(dpkg-architecture -qDEB_HOST_MULTIARCH) && \
    apt-get update && apt-get install -y \
    git  \
    libzip-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libxml2-dev \
    libonig-dev \
    libcurl4-openssl-dev \
    libldap2-dev \
    libc-client-dev \
    libkrb5-dev \
    libicu-dev \
    libssl-dev \
    unzip \
    && ln -s /usr/include/$ARCH/gssapi /usr/include/gssapi

# Install PHP extensions
RUN docker-php-ext-install \
    mysqli \
    pdo_mysql \
    ldap \
    gd \
    zip \
    soap \
    mbstring

# Install imap PHP extension separately with specific flags
RUN docker-php-source extract && \
    docker-php-ext-configure imap --with-kerberos --with-imap-ssl && \
    docker-php-ext-install imap && \
    docker-php-source delete

# Install apcu
RUN pecl install apcu && docker-php-ext-enable apcu

# configuration option "php_ini" is not set to php.ini location
# You should add "extension=apcu.so" to php.ini

# Prepare libs for multiarch image
RUN ARCH=$(dpkg-architecture -qDEB_HOST_MULTIARCH) && \
    mkdir -p /tmp/lib/$ARCH/ && \
    cp /usr/lib/$ARCH/libzip.so.4 /tmp/lib/$ARCH/libzip.so.4

# Get and extract iTop
RUN mkdir -p ${ITOP_TMP} \
    && curl -SL -o ${ITOP_TMP}/itop.zip ${ITOP_DOWNLOAD_URL} \
    && unzip ${ITOP_TMP}/itop.zip -d ${ITOP_TMP}/

FROM php:${BASE_VER}

LABEL title="Docker image with Combodo iTop"

ARG ITOP_TMP
ARG DEBIAN_FRONTEND

RUN apt-get update && apt-get install -y \
    acl \
    tzdata \
    graphviz \
    ssmtp \
    default-mysql-client

# Copy compiled extensions from builder stage
COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=builder /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d
COPY --from=builder /usr/local/bin/docker-php-ext-* /usr/local/bin/
COPY --from=builder /usr/local/lib/lib* /usr/local/lib/
COPY --from=builder /usr/lib/libc-client.so.2007e /usr/lib/
COPY --from=builder /tmp/lib/ /usr/lib/

RUN ARCH=$(dpkg-architecture -qDEB_HOST_MULTIARCH) && \
    cp /usr/lib/$ARCH/libzip.so.4 /usr/lib/

# Copy configs and scripts
COPY --chmod=644 php/ /usr/local/etc/php/conf.d/
COPY --chmod=644 apache/*.conf /etc/apache2/conf-available/

RUN a2enconf fqdn \
    && a2enconf security \
    && a2enmod headers \
    && mkdir -p /var/lib/php/sessions \
    && chown -R www-data:www-data /var/lib/php/sessions \
    && rm -rf /var/www/html

# Copy iTop code
COPY --from=builder --chown=www-data:www-data ${ITOP_TMP}/web /var/www/html

RUN setfacl -dR -m u:"www-data":rwX /var/www/html/data /var/www/html/log && \
    setfacl -R -m u:"www-data":rwX /var/www/html/data /var/www/html/log && \
    setfacl -m u:"www-data":rwX /var/www/html/

RUN mkdir -p /var/www/html/env-production \
             /var/www/html/env-production-build \
             /var/www/html/env-test \
             /var/www/html/env-test-build \
             /var/www/html/extensions && \
    chown www-data: \
            /var/www/html/conf \
            /var/www/html/env-production \
            /var/www/html/env-production-build \
            /var/www/html/env-test \
            /var/www/html/env-test-build \
            /var/www/html/extensions

WORKDIR /var/www/html

USER www-data

EXPOSE 80

HEALTHCHECK --interval=5m --timeout=3s CMD curl -f http://localhost/ || exit 1
