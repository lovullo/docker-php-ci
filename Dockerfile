FROM php:7.1-stretch

# deal with slim variants not having man page directories (which causes "update-alternatives" to fail)
RUN	if [ ! -d /usr/share/man/man1 ]; then \
		mkdir -p /usr/share/man/man1; \
	fi
# Update and Install Packages
RUN apt-get update -y && apt-get install -y \
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
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install PHP Modules
RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl && \
    docker-php-ext-install -j$(nproc) \
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

RUN cd ~/ && \
    curl -L https://github.com/websupport-sk/pecl-memcache/archive/NON_BLOCKING_IO_php7.zip -o pecl-memcache.zip && \
    unzip pecl-memcache.zip && \
    cd pecl-memcache-NON_BLOCKING_IO_php7 && \
    phpize --clean && \
    phpize && \
    ./configure && \
    make && \
    make install && \
    docker-php-ext-enable memcache && \
    cd ~/ && rm -Rf ~/pecl-memcache-NON_BLOCKING_IO_php7
RUN apt-get update && apt-get install -y libmemcached-dev zlib1g-dev \
    && pecl install memcached \
    && docker-php-ext-enable memcached

# SQLA PHP Driver
RUN curl -fsSL 'http://d5d4ifzqzkhwt.cloudfront.net/drivers/php/SQLAnywhere-php-7.1_Linux.tar.gz' -o sqlany-php71.tar.gz \
    && mkdir -p /tmp/sqlany \
    && tar -xf sqlany-php71.tar.gz -C /tmp/sqlany --strip-components=1 \
    && rm sqlany-php71.tar.gz \
    && cp /tmp/sqlany/lib64/*.so $(php -i | grep extension_dir | head -n 1 | awk '{print $3}')/ && \
    echo "extension=php-7.1.0_sqlanywhere.so" > $PHP_INI_DIR/conf.d/sqlanywhere.ini \
    && rm -r /tmp/sqlany

# Install PECL Extensions
RUN pecl install mongodb-1.4.4 \
    && docker-php-ext-enable mongodb

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
