# syntax=docker/dockerfile:1.20

ARG BUILD_VERSION
# renovate: datasource=github-releases depName=maxmind/libmaxminddb
ARG LIBMAXMINDDB_VERSION=1.12.2
# renovate: datasource=github-tags depName=xdebug/xdebug
ARG XDEBUG_VERSION=3.5.0

FROM bitnami/minideb:bookworm AS libmaxminddb_build

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
RUN mkdir -p /opt/bitnami/common/licenses && \
    cp libmaxminddb-${LIBMAXMINDDB_VERSION}/LICENSE /opt/bitnami/common/licenses/libmaxminddb-${LIBMAXMINDDB_VERSION}.txt

FROM bitnami/minideb:bookworm AS php_build

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG BUILD_VERSION

COPY --link prebuildfs/ /
RUN mkdir -p /opt/blacksmith-sandbox
RUN install_packages ca-certificates curl git build-essential unzip libssl-dev

WORKDIR /bitnami/blacksmith-sandbox

RUN install_packages gnupg && \
    (curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null) && \
    echo "deb http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list
RUN install_packages pkg-config build-essential autoconf bison re2c \
      zlib1g-dev libbz2-dev libcurl4-openssl-dev libpng-dev libwebp-dev libsqlite3-dev \
      libjpeg-dev libfreetype6-dev libgmp-dev libpam0g-dev libicu-dev libldap2-dev libonig-dev freetds-dev \
      unzip libreadline-dev libsodium-dev libtidy-dev libxslt1-dev libzip-dev libmagickwand-dev \
      libmongo-client-dev libpq-dev libkrb5-dev file

ENV EXTENSION_DIR=/opt/bitnami/php/lib/php/extensions

ADD --link https://github.com/php/php-src/archive/refs/tags/php-${BUILD_VERSION}.tar.gz php.tar.gz
RUN <<EOT bash
    set -e
    tar xf php.tar.gz
    mv php-src-php-${BUILD_VERSION} php-${BUILD_VERSION}
    cd php-${BUILD_VERSION}
    ./buildconf -f

    /bitnami/blacksmith-sandbox/php-${BUILD_VERSION}/configure --prefix=/opt/bitnami/php --with-zlib-dir --with-zlib --with-libxml-dir=/usr --enable-soap --disable-rpath \
        --enable-inline-optimization --with-bz2 --enable-sockets --enable-pcntl --enable-exif --enable-bcmath --with-pdo-mysql=mysqlnd --with-mysqli=mysqlnd --with-png-dir=/usr \
        --with-openssl --with-libdir=/lib/$(gcc -dumpmachine) --enable-ftp --enable-calendar --with-gettext --with-xmlrpc --with-xsl --enable-fpm --with-fpm-user=daemon \
        --with-fpm-group=daemon --enable-mbstring --enable-cgi --enable-ctype --enable-session --enable-mysqlnd --enable-intl --with-iconv --with-pdo_sqlite --with-sqlite3 \
        --with-readline --with-gmp --with-curl --with-pdo-pgsql=shared --with-pgsql=shared --with-config-file-scan-dir=/opt/bitnami/php/etc/conf.d --enable-simplexml \
        --with-sodium --enable-gd --with-pear --with-freetype --with-jpeg --with-webp --with-zip --with-pdo-dblib=shared --with-tidy --with-ldap=/usr/ --enable-apcu=shared \
        PKG_CONFIG_PATH=/opt/bitnami/common/lib/pkgconfig EXTENSION_DIR=/opt/bitnami/php/lib/php/extensions
    make -j$(nproc)
    make install
EOT

ENV PATH=/opt/bitnami/php/bin:$PATH
ENV LD_LIBRARY_PATH=/opt/bitnami/lib

# renovate: datasource=github-releases depName=php/pie
ARG PIE_VERSION=1.3.3
ADD --link https://github.com/php/pie/releases/download/${PIE_VERSION}/pie.phar /opt/bitnami/php/bin/pie
RUN chmod 755 /opt/bitnami/php/bin/pie

# renovate: datasource=github-releases depName=composer/composer
ARG COMPOSER_VERSION=2.9.2
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php --install-dir=/opt/bitnami/php/bin --version=$COMPOSER_VERSION && \
    ln -sv /opt/bitnami/php/bin/composer.phar /opt/bitnami/php/bin/composer

COPY --link --from=libmaxminddb_build /opt/bitnami /opt/bitnami
COPY --link rootfs/ /

# renovate: datasource=github-releases depName=php-memcached-dev/php-memcached
ARG MEMCACHED_VERSION=3.4.0
# renovate: datasource=github-releases depName=krakjoe/apcu extractVersion=^v(?<version>.*)$
ARG APCU_VERSION=5.1.28
# renovate: datasource=github-releases depName=Imagick/imagick
ARG IMAGICK_VERSION=3.8.1
# renovate: datasource=github-releases depName=mongodb/mongo-php-driver
ARG MONGODB_VERSION=2.1.4
ARG XDEBUG_VERSION
# renovate: datasource=github-releases depName=maxmind/MaxMind-DB-Reader-php extractVersion=^v(?<version>.*)$
ARG MAXMIND_READER_VERSION=1.13.1

RUN pie install apcu/apcu:$APCU_VERSION && \
    pie install imagick/imagick:$IMAGICK_VERSION

RUN <<EOT
  set -eux
  mkdir -p /opt/bitnami/common/licenses

  git clone https://github.com/awslabs/aws-elasticache-cluster-client-libmemcached.git
  cd aws-elasticache-cluster-client-libmemcached
  touch configure.ac aclocal.m4 configure Makefile.am Makefile.in
  mkdir BUILD
  cd BUILD
  ../configure --with-pic --disable-sasl
  make -j$(nproc) && make install
  cp ../LICENSE /opt/bitnami/common/licenses/libmemcached-1.0.18.txt
  cd ../..
  rm -rf aws-elasticache-cluster-client-libmemcached

  git clone -b php8.x https://github.com/awslabs/aws-elasticache-cluster-client-memcached-for-php.git
  cd aws-elasticache-cluster-client-memcached-for-php
  phpize
  mkdir BUILD
  cd BUILD
  ../configure --disable-memcached-sasl
  make -j$(nproc) && make install
  cp ../LICENSE /opt/bitnami/common/licenses/aws-elasticache-cluster-client-memcached-for-php-3.2.0.txt
  cd ../..
  rm -rf aws-elasticache-cluster-client-memcached-for-php
EOT
RUN PKG_CONFIG_PATH=/opt/bitnami/common/lib/pkgconfig:\$PKG_CONFIG_PATH pie install maxmind-db/reader-ext:$MAXMIND_READER_VERSION
RUN pie install mongodb/mongodb-extension:$MONGODB_VERSION
RUN pie install xdebug/xdebug:$XDEBUG_VERSION

RUN mkdir -p /opt/bitnami/php/logs && \
    mkdir -p /opt/bitnami/php/tmp && \
    mkdir -p /opt/bitnami/php/var/log && \
    mkdir -p /opt/bitnami/php/var/run

RUN find /opt/bitnami/ -name "*.so*" -type f | xargs strip --strip-debug
RUN find /opt/bitnami/ -executable -type f | xargs strip --strip-unneeded || true
RUN mkdir -p /opt/bitnami/php/etc/conf.d

ADD --link https://raw.githubusercontent.com/composer/composer/$COMPOSER_VERSION/LICENSE /opt/bitnami/php/licenses/composer-$COMPOSER_VERSION.txt
ADD --link https://raw.githubusercontent.com/php-memcached-dev/php-memcached/v$MEMCACHED_VERSION/LICENSE /opt/bitnami/php/licenses/libmemcached-$MEMCACHED_VERSION.txt
ADD --link https://raw.githubusercontent.com/krakjoe/apcu/v$APCU_VERSION/LICENSE /opt/bitnami/php/licenses/ext-apcu-$APCU_VERSION.txt
ADD --link https://raw.githubusercontent.com/Imagick/imagick/$IMAGICK_VERSION/LICENSE /opt/bitnami/php/licenses/ext-imagick-$IMAGICK_VERSION.txt
ADD --link https://raw.githubusercontent.com/mongodb/mongo-php-driver/$MONGODB_VERSION/LICENSE /opt/bitnami/php/licenses/ext-mongodb-$MONGODB_VERSION.txt
ADD --link https://raw.githubusercontent.com/xdebug/xdebug/$XDEBUG_VERSION/LICENSE /opt/bitnami/php/licenses/ext-xdebug-$XDEBUG_VERSION.txt
ADD --link https://raw.githubusercontent.com/maxmind/MaxMind-DB-Reader-php/v$MAXMIND_READER_VERSION/LICENSE /opt/bitnami/php/licenses/maxmind-db-reader-php-$MAXMIND_READER_VERSION.txt
RUN cp /bitnami/blacksmith-sandbox/php-${BUILD_VERSION}/LICENSE /opt/bitnami/php/licenses/php-$BUILD_VERSION.txt
RUN mkdir -p /opt/bitnami/php/lib && ln -sv ../etc/php.ini /opt/bitnami/php/lib/php.ini

RUN php -i # Test run executable

ARG DIRS_TO_TRIM="/opt/bitnami/php/lib/php/test \
    /opt/bitnami/php/lib/php/doc \
    /opt/bitnami/php/php/man \
"

RUN <<EOT bash
    for DIR in $DIRS_TO_TRIM; do
      find \$DIR/ -delete -print
    done
EOT

FROM bitnami/minideb:bookworm AS stage-0

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
    install_packages ca-certificates curl gzip libbsd0 libbz2-1.0 libc6 libcom-err2 libcurl4 libexpat1 libffi8 libfftw3-double3  \
        libfontconfig1 libfreetype6 libgcc1 libgcrypt20 libbrotli1 libglib2.0-0 libgmp10 libgnutls30 libgomp1 libgpg-error0 libgssapi-krb5-2  \
        libhogweed6 libicu72 libidn2-0 libjpeg62-turbo libk5crypto3 libkeyutils1 libkrb5-3 libkrb5support0 liblcms2-2 libldap-2.5-0  \
        liblqr-1-0 libltdl7 liblzma5 libmagickcore-6.q16-6 libmagickwand-6.q16-6 libhashkit2 libsqlite3-0 libwebp7 perl  \
        libnettle8 libnghttp2-14 libonig5 libp11-kit0 libpng16-16 libpq5 libpsl5 libreadline8 librtmp1 libsasl2-2  \
        libsodium23 libssh2-1 libssl3 libstdc++6 libsybdb5 libtasn1-6 libtidy5deb1 libtinfo6 libunistring2 libuuid1 libx11-6  \
        libxau6 libxcb1 libxdmcp6 libxext6 libxslt1.1 libzip4 procps tar zlib1g libgdbm6 libxml2

    for DIR in $DIRS_TO_TRIM; do
      find \$DIR/ -delete -print
    done
    rm /var/cache/ldconfig/aux-cache

    mkdir -p /app
    mkdir -p /var/log/apt
    mkdir -p /tmp
    chmod 1777 /tmp
    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS    90/' /etc/login.defs
    sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS    0/' /etc/login.defs
    sed -i 's/sha512/sha512 minlen=8/' /etc/pam.d/common-password
    find /usr/share/doc -mindepth 2 -not -name copyright -not -type d -delete
    find /usr/share/doc -mindepth 1 -type d -empty -delete
EOT

COPY --link rootfs/ /
COPY --from=php_build /opt/bitnami /opt/bitnami
COPY --from=php_build /usr/local/lib/libhashkit*.so* /usr/local/lib/
COPY --from=php_build /usr/local/lib/libmemcached*.so* /usr/local/lib/

ARG BUILD_VERSION
ARG TARGETARCH
ENV APP_VERSION=$BUILD_VERSION \
    BITNAMI_APP_NAME=php-fpm \
    PATH="/opt/bitnami/php/bin:/opt/bitnami/php/sbin:$PATH" \
    OS_ARCH=$TARGETARCH \
    OS_FLAVOUR="debian-12" \
    OS_NAME="linux"

EXPOSE 9000
WORKDIR /app

CMD ["php-fpm", "-F", "--pid", "/opt/bitnami/php/tmp/php-fpm.pid", "-y", "/opt/bitnami/php/etc/php-fpm.conf"]

