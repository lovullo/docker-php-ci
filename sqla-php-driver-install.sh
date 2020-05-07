#!/usr/bin/env bash
set -ex
set -o pipefail

PHPVERNUM=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
export PHPVERNUM
echo "PHPVERNUM: ${PHPVERNUM}"

# Check which php version we are using and download or build, since PHP 7.4 doesn't have prebuilt drivers
if [ "${PHPVERNUM}" != "7.4" ]; then
  # Script to download and install the sqlanywhere driver
  curl -fsSL "http://d5d4ifzqzkhwt.cloudfront.net/drivers/php/SQLAnywhere-php-${PHPVERNUM}_Linux.tar.gz" -o sqlany-php.tar.gz
  mkdir -p sqlany
  tar -xf sqlany-php.tar.gz -C sqlany --strip-components=1
  cp sqlany/lib64/*.so "$(php -i | grep extension_dir | head -n 1 | awk '{print $3}')/"
  #echo "extension=$(basename  "$(ls sqlany/lib64/*sqlanywhere.so)")" > "${PHP_INI_DIR}/conf.d/sqlanywhere.ini"
  docker-php-ext-enable "$(basename  "$(ls sqlany/lib64/*sqlanywhere.so)")"
  rm -Rf sqlany
  rm sqlany-php.tar.gz
  php -m | grep sqlanywhere
else
  # Script to build the sqlanywhere php driver
  curl --fail --silent https://s3.amazonaws.com/sqlanywhere/drivers/php/sasql_php.zip -o sasql_php.zip
  unzip -t sasql_php.zip
  unzip -d sasql-php sasql_php.zip
  cd sasql-php
  phpize
  ./configure
  make
  make test
  PHPEXTDIR=$(php -i | grep -v 'sqlite3.extension_dir' | grep extension_dir | awk '{print $3}')
  echo ${PHPEXTDIR}
  cp modules/sqlanywhere.* "/${PHPEXTDIR}/"
  echo "extension=$(basename  "${PHPEXTDIR}/sqlanywhere.so")" > "${PHP_INI_DIR}/conf.d/sqlanywhere.ini"
  cd ..
  rm -Rf sasql-php
  php -m | grep sqlanywhere
fi
