#!/bin/sh

# ------------------------------------------------------------------------------
# This is free and unencumbered software released into the public domain.
#
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.
#
# In jurisdictions that recognize copyright laws, the author or authors
# of this software dedicate any and all copyright interest in the
# software to the public domain. We make this dedication for the benefit
# of the public at large and to the detriment of our heirs and
# successors. We intend this dedication to be an overt act of
# relinquishment in perpetuity of all present and future rights to this
# software under copyright law.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# For more information, please refer to <http://unlicense.org>
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Script to compile PHP from source.
#
# AUTHOR: Richard Fussenegger <richard@fussenegger.info>
# COPYRIGHT: Copyright (c) 2015 Richard Fussenegger
# LICENSE: http://unlicense.org/ PD
# LINK: http://richard.fussenegger.info/
# ------------------------------------------------------------------------------

# Check return status of every command.
set -e

# ------------------------------------------------------------------------------
#                                                    User configurable variables
# ------------------------------------------------------------------------------

# Version string of the PHP release that should be compiled and installed.
readonly PHP_VERSION='5.6.6'

# PHP-FPM system user.
readonly PHP_FPM_USER='www-data'

# PHP-FPM system group.
readonly PHP_FPM_GROUP='www-data'

# The bison version required to compile PHP.
readonly BISON_MAX_VERSION='3.0'

# Absolute path to the configuration files.
readonly CONFIGURATION_DIRECTORY='/etc/php'

# Absolute path to the directory where source files should be kept.
readonly SOURCE_DIRECTORY='/usr/local/src'

# ------------------------------------------------------------------------------
#                                                               System variables
# ------------------------------------------------------------------------------

# Make sure that no questions are asked by the operatin system.
export DEBIAN_FRONTEND='noninteractive'

# Absolute path to the directory of the current script.
readonly __DIRNAME__="$(cd -- "$(dirname -- "${0}")"; pwd)"

# For more information on shell colors and other text formatting see:
# http://stackoverflow.com/a/4332530/1251219
readonly RED=$(tput bold; tput setaf 1)
readonly GREEN=$(tput bold; tput setaf 2)
readonly YELLOW=$(tput bold; tput setaf 3)
readonly NORMAL=$(tput sgr0)

# ------------------------------------------------------------------------------
#                                                                      Functions
# ------------------------------------------------------------------------------

# Install bison 2.7.1
install_bison()
{
    # We need an older version of bison to compile PHP: http://askubuntu.com/a/461961
    wget -- 'http://launchpadlibrarian.net/140087283/libbison-dev_2.7.1.dfsg-1_amd64.deb'
    wget -- 'http://launchpadlibrarian.net/140087282/bison_2.7.1.dfsg-1_amd64.deb'
    dpkg -i 'libbison-dev_2.7.1.dfsg-1_amd64.deb'
    dpkg -i 'bison_2.7.1.dfsg-1_amd64.deb'
    rm --force -- 'libbison-dev_2.7.1.dfsg-1_amd64.deb' 'bison_2.7.1.dfsg-1_amd64.deb'
}

# Print usage text.
usage()
{
    cat << EOT
Usage: ${0##*/} [OPTION]...
Compile and install PHP from source.

    -h  Display this help and exit.

Report bugs to richard@fussenegger.info
GitHub repository: https://githbu.com/Fleshgrinder/php-compile
For complete documentation, see: README.md
EOT
}

# ------------------------------------------------------------------------------
#                                                                          Logic
# ------------------------------------------------------------------------------

# Check for possibly passed options.
while getopts 'h' OPT
do
    case "${OPT}" in
        h|[?]) usage && exit 0 ;;
    esac

    # We have to remove found options from the input for later evaluations of
    # passed arguments in subscripts that are not interested in these options.
    shift $(( $OPTIND - 1 ))
done

# Remove possibly passed end of options marker.
if [ "${1}" = "--" ]
    then shift $(( $OPTIND - 1 ))
fi

printf -- 'Updating package sources ...\n'
apt-get --yes -- update 1>/dev/null

printf -- 'Installing dependencies ...\n'
apt-get --yes -- install \
    autoconf             \
    automake             \
    build-essential      \
    libcurl4-openssl-dev \
    libgmp-dev           \
    libicu-dev           \
    libjpeg-dev          \
    libmcrypt-dev        \
    libpng12-dev         \
    libpq-dev            \
    libssl-dev           \
    libtidy-dev          \
    libtool              \
    libxml2-dev          \
    re2c                 \
    wget

if type bison
then
    printf -- 'Found bison binary ...\n'

    # Get the version fromt he installed bison binary and remove the dots.
    BISON_VERSION=$(bison --version | grep --only-matching -- '[0-9]\.[0-9]' | tr --delete .)
    if [ "${BISON_VERSION}" -ge $(tr --delete . "${BISON_MAX_VERSION}") ]
    then
        printf -- 'Installed bison version exceeds maximum version %s!\n' "${RED}${BISON_MAX_VERSION}${NORMAL}"
        printf -- 'Purging bison installation.\n'
        apt-get --yes -- purge bison
        install_bison
    fi
else
    printf -- 'Installing bison %s2.7.1%s ...\n' "${GREEN}" "${NORMAL}"
    install_bison
fi

# The GMP header files are installed in a path PHP will not search at.
if [ ! -e '/usr/include/gmp.h' ]
    then ln --symbolic '/usr/include/x86_64-linux-gnu/gmp.h' '/usr/include/gmp.h'
fi

printf -- 'Installing PHP %s ...\n' "${YELLOW}${PHP_VERSION}${NORMAL}"

# Make sure we operate from the correct directory.
cd -- "${SOURCE_DIRECTORY}"

readonly PHP_SOURCE="${SOURCE_DIRECTORY}/php"

# Checkout PHP source files.
if [ -d "${PHP_SOURCE}/.git" ]
then
    cd -- "${PHP_SOURCE}"
    git pull
else
    rm --recursive --force -- "${PHP_SOURCE}"
    git clone --branch "PHP-${PHP_VERSION}" --depth 1 --single-branch -- https://github.com/php/php-src.git "${PHP_SOURCE}"
fi

# Make sure all files belong to the root user.
chown --recursive -- root:root "${PHP_SOURCE}"

# Make sure we are in the correct directory for compilation.
cd -- "${PHP_SOURCE}"

# Make sure the configure script is up-to-date (only necessary if building from git).
./buildconf --force

# Have a loot at the following page for available extensions:
# https://php.net/extensions.membership
CFLAGS='-O3 -m64 -march=native -pipe -DMYSQLI_NO_CHANGE_USER_ON_PCONNECT' \
CPPFLAGS="${CFLAGS}" \
LDFLAGS='' \
./configure \
    --disable-rpath \
    --disable-short-tags \
    --enable-bcmath \
    --enable-exif \
    --enable-fpm \
    --enable-inline-optimization \
    --enable-intl \
    --enable-libgcc \
    --enable-mbstring \
    --enable-pcntl \
    --enable-re2c-cgoto \
    --enable-zip \
    --sysconfdir="${CONFIGURATION_DIRECTORY}" \
    --with-config-file-path="${CONFIGURATION_DIRECTORY}" \
    --with-config-file-scan-dir="${CONFIGURATION_DIRECTORY}/conf-enabled" \
    --with-curl \
    --with-fpm-group="${PHP_FPM_GROUP}" \
    --with-fpm-user="${PHP_FPM_USER}" \
    --with-gd \
    --with-gmp \
    --with-jpeg-dir \
    --with-mcrypt \
    --with-mysqli=mysqlnd \
    --with-openssl \
    --with-pdo-mysql=mysqlnd \
    --with-pdo-pgsql \
    --with-pear \
    --with-pgsql \
    --with-png-dir \
    --with-tidy \
    --with-zlib \
    --with-zlib-dir

make clean
make
make install

cat << EOT

[${GREEN}ok${NORMAL}] Installation finished.

CONFIG: ${YELLOW}${CONFIGURATION_DIRECTORY}${NORMAL}

You may want to delete the source files in ${YELLOW}${SOURCE_DIRECTORY}${NORMAL}.

EOT

exit 0
