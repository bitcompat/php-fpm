# syntax=docker/dockerfile:1.4

ARG PHP_VERSION
# renovate: datasource=github-releases depName=maxmind/libmaxminddb
ARG LIBMAXMINDDB_VERSION=1.6.0
# renovate: datasource=github-releases depName=xdebug/xdebug
ARG XDEBUG_VERSION=3.1.5

FROM bitnami/minideb:bullseye as libmaxminddb_build

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG LIBMAXMINDDB_VERSION

RUN mkdir -p /bitnami/blacksmith-sandbox
RUN install_packages ca-certificates curl git build-essential

WORKDIR /bitnami/blacksmith-sandbox

RUN curl -sSL -olibmaxminddb.tar.gz https://github.com/maxmind/libmaxminddb/releases/download/${LIBMAXMINDDB_VERSION}/libmaxminddb-${LIBMAXMINDDB_VERSION}.tar.gz && \
    tar xf libmaxminddb.tar.gz

RUN cd libmaxminddb-${LIBMAXMINDDB_VERSION} && \
    ./configure --prefix=/opt/bitnami/common && \
    make -j4 && \
    make install

RUN rm -rf /opt/bitnami/common/lib/libmaxminddb.a /opt/bitnami/common/lib/libmaxminddb.la /opt/bitnami/common/share
RUN mkdir -p /opt/bitnami/licenses && \
    cp libmaxminddb-${LIBMAXMINDDB_VERSION}/LICENSE /opt/bitnami/licenses/libmaxminddb-${LIBMAXMINDDB_VERSION}.txt

FROM bitnami/minideb:bullseye as imap_build

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN mkdir -p /opt/blacksmith-sandbox
RUN install_packages ca-certificates curl git build-essential unzip libpam0g-dev libssl-dev libkrb5-dev

WORKDIR /bitnami/blacksmith-sandbox

RUN curl -sSL -oimap.zip https://github.com/uw-imap/imap/archive/refs/heads/master.zip && \
    unzip imap.zip && \
    mv imap-master imap-2007.0.0

RUN cd imap-2007.0.0 && \
    touch ip6 && \
    make ldb IP=6 SSLTYPE=unix.nopwd EXTRACFLAGS=-fPIC

FROM bitnami/minideb:bullseye as php_build

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG PHP_VERSION

COPY --link prebuildfs/ /
RUN mkdir -p /opt/blacksmith-sandbox
RUN install_packages ca-certificates curl git build-essential unzip libssl-dev

WORKDIR /bitnami/blacksmith-sandbox

COPY --link --from=imap_build /bitnami/blacksmith-sandbox/imap-2007.0.0 /bitnami/blacksmith-sandbox/imap-2007.0.0
RUN install_packages gnupg && \
    (curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null) && \
    echo "deb http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" > /etc/apt/sources.list.d/pgdg.list
RUN install_packages pkg-config build-essential autoconf bison re2c \
      zlib1g-dev libbz2-dev libcurl4-openssl-dev libpng-dev libwebp-dev libsqlite3-dev \
      libjpeg-dev libfreetype6-dev libgmp-dev libpam0g-dev libicu-dev libldap2-dev libonig-dev freetds-dev \
      unzip libreadline-dev libsodium-dev libtidy-dev libxslt1-dev libzip-dev libmemcached-dev libmagickwand-dev \
      libmongo-client-dev libpq-dev libkrb5-dev file

ENV EXTENSION_DIR=/opt/bitnami/php/lib/php/extensions

ADD --link https://github.com/php/php-src/archive/refs/tags/php-${PHP_VERSION}.tar.gz php.tar.gz
RUN <<EOT bash
    set -e
    tar xf php.tar.gz
    mv php-src-php-${PHP_VERSION} php-${PHP_VERSION}
    cd php-${PHP_VERSION}
    ./buildconf -f

    /bitnami/blacksmith-sandbox/php-${PHP_VERSION}/configure --prefix=/opt/bitnami/php --with-imap=/bitnami/blacksmith-sandbox/imap-2007.0.0 --with-imap-ssl --with-zlib --with-libxml-dir=/usr --enable-soap --disable-rpath --enable-inline-optimization --with-bz2 \
        --enable-sockets --enable-pcntl --enable-exif --enable-bcmath --with-pdo-mysql=mysqlnd --with-mysqli=mysqlnd --with-png-dir=/usr --with-openssl --with-libdir=/lib/$(gcc -dumpmachine) --enable-ftp --enable-calendar --with-gettext --with-xmlrpc --with-xsl --enable-fpm \
        --with-fpm-user=daemon --with-fpm-group=daemon --enable-mbstring --enable-cgi --enable-ctype --enable-session --enable-mysqlnd --enable-intl --with-iconv --with-pdo_sqlite --with-sqlite3 --with-readline --with-gmp --with-curl --with-pdo-pgsql=shared \
        --with-pgsql=shared --with-config-file-scan-dir=/opt/bitnami/php/etc/conf.d --enable-simplexml --with-sodium --enable-gd --with-pear --with-freetype --with-jpeg --with-webp --with-zip --with-pdo-dblib=shared --with-tidy --with-ldap=/usr/ --enable-apcu=shared --enable-opcache
    make -j$(nproc)
    make install
EOT

RUN cp /bitnami/blacksmith-sandbox/imap-2007.0.0/LICENSE /opt/bitnami/licenses/imap-2007.0.0.txt

ENV PATH=/opt/bitnami/php/bin:$PATH
ENV LD_LIBRARY_PATH=/opt/bitnami/lib

# renovate: datasource=github-releases depName=composer/composer
ARG COMPOSER_VERSION=2.4.1

RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php --install-dir=/opt/bitnami/php/bin --version=$COMPOSER_VERSION && \
    ln -sv /opt/bitnami/php/bin/composer.phar /opt/bitnami/php/bin/composer

COPY --link --from=libmaxminddb_build /opt/bitnami /opt/bitnami
COPY --link rootfs/ /

# renovate: datasource=github-releases depName=php-memcached-dev/php-memcached
ARG MEMCACHED_VERSION=3.2.0
# renovate: datasource=github-releases depName=krakjoe/apcu extractVersion=^v(?<version>.*)$
ARG APCU_VERSION=5.1.21
# renovate: datasource=github-releases depName=Imagick/imagick
ARG IMAGICK_VERSION=3.7.0
# renovate: datasource=github-releases depName=mongodb/mongo-php-driver
ARG MONGODB_VERSION=1.14.0
ARG XDEBUG_VERSION
# renovate: datasource=github-releases depName=maxmind/MaxMind-DB-Reader-php extractVersion=^v(?<version>.*)$
ARG MAXMIND_READER_VERSION=1.11.0

RUN pecl install apcu-$APCU_VERSION
RUN pecl install imagick-$IMAGICK_VERSION
RUN pecl install memcached-$MEMCACHED_VERSION
RUN PKG_CONFIG_PATH=/opt/bitnami/common/lib/pkgconfig:\$PKG_CONFIG_PATH pecl install maxminddb-$MAXMIND_READER_VERSION
RUN pecl install mongodb-$MONGODB_VERSION
RUN pecl install xdebug-$XDEBUG_VERSION

RUN mkdir -p /opt/bitnami/php/logs && \
    mkdir -p /opt/bitnami/php/tmp && \
    mkdir -p /opt/bitnami/php/var/log && \
    mkdir -p /opt/bitnami/php/var/run

RUN find /opt/bitnami/ -name "*.so*" -type f | xargs strip --strip-debug
RUN find /opt/bitnami/ -executable -type f | xargs strip --strip-unneeded || true
RUN mkdir -p /opt/bitnami/php/etc/conf.d

ADD --link https://raw.githubusercontent.com/composer/composer/$COMPOSER_VERSION/LICENSE /opt/bitnami/licenses/composer-$COMPOSER_VERSION.txt
ADD --link https://raw.githubusercontent.com/php-memcached-dev/php-memcached/v$MEMCACHED_VERSION/LICENSE /opt/bitnami/licenses/libmemcached-$MEMCACHED_VERSION.txt
ADD --link https://raw.githubusercontent.com/krakjoe/apcu/v$APCU_VERSION/LICENSE /opt/bitnami/licenses/peclapcu-$APCU_VERSION.txt
ADD --link https://raw.githubusercontent.com/Imagick/imagick/$IMAGICK_VERSION/LICENSE /opt/bitnami/licenses/peclimagick-$IMAGICK_VERSION.txt
ADD --link https://raw.githubusercontent.com/mongodb/mongo-php-driver/$MONGODB_VERSION/LICENSE /opt/bitnami/licenses/peclmongodb-$MONGODB_VERSION.txt
ADD --link https://raw.githubusercontent.com/xdebug/xdebug/$XDEBUG_VERSION/LICENSE /opt/bitnami/licenses/peclxdebug-$XDEBUG_VERSION.txt
ADD --link https://raw.githubusercontent.com/maxmind/MaxMind-DB-Reader-php/v$MAXMIND_READER_VERSION/LICENSE /opt/bitnami/licenses/maxmind-db-reader-php-$MAXMIND_READER_VERSION.txt
RUN cp /bitnami/blacksmith-sandbox/php-${PHP_VERSION}/LICENSE /opt/bitnami/licenses/php-$PHP_VERSION.txt
RUN mkdir -p /opt/bitnami/php/lib && ln -sv ../etc/php.ini /opt/bitnami/php/lib/php.ini

RUN php -i # Test run executable

ARG DIRS_TO_TRIM="/opt/bitnami/php/lib/php/test \
    /opt/bitnami/php/lib/php/doc \
    /opt/bitnami/php/php/man \
    /opt/bitnami/php/lib/php/.registry/.channel.pecl.php.net \
"

RUN <<EOT bash
    for DIR in $DIRS_TO_TRIM; do
      find \$DIR/ -delete -print
    done
EOT

FROM bitnami/minideb:bullseye as stage-0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG DIRS_TO_TRIM="/usr/share/man \
    /var/cache/apt \
    /usr/share/locale \
    /var/log \
    /usr/share/info \
    /tmp \
"

RUN <<EOT bash
    set -e
    install_packages ca-certificates curl gzip git libbsd0 libbz2-1.0 libc6 libcom-err2 libcurl4 libcurl3-gnutls libexpat1 libffi7 libfftw3-double3  \
        libfontconfig1 libfreetype6 libgcc1 libgcrypt20 libglib2.0-0 libgmp10 libgnutls30 libgomp1 libgpg-error0 libgssapi-krb5-2  \
        libhogweed6 libicu67 libidn2-0 libjpeg62-turbo libk5crypto3 libkeyutils1 libkrb5-3 libkrb5support0 liblcms2-2 libldap-2.4-2  \
        liblqr-1-0 libltdl7 liblzma5 libmagickcore-6.q16-6 libmagickwand-6.q16-6 libmemcached11 libncurses6 perl  \
        libnettle8 libnghttp2-14 libonig5 libp11-kit0 libpcre3 libpng16-16 libpq5 libpsl5 libreadline8 librtmp1 libsasl2-2  \
        libsodium23 libssh2-1 libssl1.1 libstdc++6 libsybdb5 libtasn1-6 libtidy5deb1 libtinfo6 libunistring2 libuuid1 libx11-6  \
        libxau6 libxcb1 libxdmcp6 libxext6 libxslt1.1 libzip4 procps tar zlib1g libgdbm6 sqlite3

    for DIR in $DIRS_TO_TRIM; do
      find \$DIR/ -delete -print
    done
    rm /var/cache/ldconfig/aux-cache

    mkdir -p /app
    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS    90/' /etc/login.defs
    sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS    0/' /etc/login.defs
    sed -i 's/sha512/sha512 minlen=8/' /etc/pam.d/common-password
    find /usr/share/doc -mindepth 2 -not -name copyright -not -type d -delete
    find /usr/share/doc -mindepth 1 -type d -empty -delete
EOT

COPY --from=php_build /opt/bitnami /opt/bitnami

ARG PHP_VERSION
ARG TARGETARCH
ENV APP_VERSION=$PHP_VERSION \
    BITNAMI_APP_NAME=php-fpm \
    BITNAMI_IMAGE_VERSION="${PHP_VERSION}-prod-debian-11" \
    PATH="/opt/bitnami/php/bin:/opt/bitnami/php/sbin:$PATH" \
    OS_ARCH=$TARGETARCH \
    OS_FLAVOUR="debian-11" \
    OS_NAME="linux"

EXPOSE 9000
WORKDIR /app

CMD ["php-fpm", "-F", "--pid", "/opt/bitnami/php/tmp/php-fpm.pid", "-y", "/opt/bitnami/php/etc/php-fpm.conf"]

