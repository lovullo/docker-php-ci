# Default php version to use can be overidden when building
ARG PHPVER=7.2-cli
FROM php:$PHPVER

# deal with slim variants not having man page directories (which causes "update-alternatives" to fail)
RUN if [ ! -d /usr/share/man/man1 ]; then \
        mkdir -p /usr/share/man/man1; \
    fi

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=America/New_York
WORKDIR /tmp/
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Update and Install Packages
# Ignoring: DL3008 Pin versions
# hadolint ignore=DL3008
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    apt-get update -y && \
    apt-get install --no-install-recommends -y \
        ant \
        curl \
        git \
        libc-client-dev \
        libcurl4-gnutls-dev \
        libfreetype6-dev \
        libkrb5-dev \
        libxslt1-dev \
        libxslt1.1 \
        openssh-client \
        rsync \
        unzip \
        libzip-dev \
        zlib1g-dev \
        libmemcached-dev \
        re2c && \
    rm -rf /var/lib/apt/lists/*

# Install PHP Modules
RUN PHP_OPENSSL="yes" docker-php-ext-configure imap --with-kerberos --with-imap-ssl && \
    docker-php-ext-install -j"$(nproc)" \
        bcmath \
        curl \
        gd \
        imap \
        json \
        mysqli \
        soap \
        sockets \
        xsl \
        zip

# Ignoring: DL3003 Use WORKDIR
# hadolint ignore=DL3003
RUN curl -L https://github.com/websupport-sk/pecl-memcache/archive/NON_BLOCKING_IO_php7.zip -o pecl-memcache.zip && \
    unzip pecl-memcache.zip && \
    cd pecl-memcache-NON_BLOCKING_IO_php7 && \
    phpize --clean && \
    phpize && \
    ./configure && \
    make && \
    make install && \
    docker-php-ext-enable memcache && \
    cd ..  && \
    rm -Rf pecl-memcache-NON_BLOCKING_IO_php7

RUN pecl install memcached && \
    docker-php-ext-enable memcached && \
    php -m | grep memcached

# Install sqlanywhere/SQLA Client Library
# Ignoring: DL3003 Use WORKDIR
# hadolint ignore=DL3003
RUN curl -fsSL http://d5d4ifzqzkhwt.cloudfront.net/sqla17client/sqla17_client_linux_x86x64.tar.gz -o sqla17_client_linux_x86x64.tar.gz && \
    tar -xzvpf sqla17_client_linux_x86x64.tar.gz && \
    cd client1700 && \
    ./setup -nogui -silent -I_accept_the_license_agreement -install sqlany_client32,sqlany_client64,ultralite64 && \
    cd .. && \
    rm -Rf client1700 && \
    rm -Rf sqla17_client_linux_x86x64.tar.gz

ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/libfakeroot:/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu:/opt/sqlanywhere17/lib64
# Install sqlanywhere/SQLA PHP Driver
RUN PHPVERNUM="$(echo "$PHP_VERSION" | awk -F '\.' '{print $1"."$2}')" && \
    export PHPVERNUM && \
    echo "PHPVERNUM: ${PHPVERNUM}" && \
    curl -fsSL "http://d5d4ifzqzkhwt.cloudfront.net/drivers/php/SQLAnywhere-php-${PHPVERNUM}_Linux.tar.gz" -o sqlany-php.tar.gz && \
    mkdir -p sqlany && \
    tar -xf sqlany-php.tar.gz -C sqlany --strip-components=1 && \
    cp sqlany/lib64/*.so "$(php -i | grep extension_dir | head -n 1 | awk '{print $3}')/" && \
    echo "extension=$(basename  "$(ls sqlany/lib64/*sqlanywhere.so)")" > "${PHP_INI_DIR}/conf.d/sqlanywhere.ini" && \
    rm -Rf sqlany && \
    rm sqlany-php.tar.gz && \
    php -m | grep sqlanywhere

# Install PECL Extensions
RUN pecl install mongodb-1.4.4 && \
    docker-php-ext-enable mongodb && \
    php -m | grep mongodb

# Fix php memory limit so that the phpdbg/phpunit test doesn't fail
RUN echo "memory_limit = 256M" > "/usr/local/etc/php/conf.d/memory-limit.ini"

# Display all errors by default
RUN echo "error_reporting = E_ALL & ~E_DEPRECATED" > "/usr/local/etc/php/conf.d/error-reporting.ini"

# Install Composer
RUN curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
    && curl -o /tmp/composer-setup.sig https://composer.github.io/installer.sig \
    && php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1);  }" \
    && php /tmp/composer-setup.php --no-ansi --install-dir=/usr/local/bin --filename=composer \
    && rm /tmp/composer-setup.php

# Install Ant libraries
RUN curl -O http://dl.google.com/closure-compiler/compiler-20161201.tar.gz && \
    tar -xzvf compiler-20161201.tar.gz closure-compiler-v20161201.jar && \
    mv -v closure-compiler-v20161201.jar /usr/share/ant/lib/closure-compiler.jar && \
    chown root:root /usr/share/ant/lib/closure-compiler.jar && \
    chmod 0644 /usr/share/ant/lib/closure-compiler.jar && \
    rm compiler-20161201.tar.gz

# Disable host key checking from within builds as we cannot interactively accept them
# TODO: It might be a better idea to bake ~/.ssh/known_hosts into the container
RUN mkdir -p ~/.ssh
RUN printf "Host *\n\tStrictHostKeyChecking no\n\n" > ~/.ssh/config
