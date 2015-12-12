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
# Makefile to compile and install PHP and composer.
#
# AUTHOR: Richard Fussenegger <richard@fussenegger.info>
# COPYRIGHT: Copyright (c) 2015 Richard Fussenegger
# LICENSE: http://unlicense.org/ PD
# LINK: http://richard.fussenegger.info/
# ------------------------------------------------------------------------------

SHELL = /bin/sh
.SUFFIXES:

COMPOSER_BIN        := /usr/local/bin/composer
PHP_CONFIGURATION   := /user/local/etc/php
PHP_FPM_INIT_SCRIPT := /usr/local/src/php-fpm-sysvinit-script

all:
	make -- php composer

install:
	make -- php composer

uninstall:
	make -- uninstall-php uninstall-composer

php:
	git clone https://github.com/Fleshgrinder/php-configuration.git '$(PHP_CONFIGURATION)' 2>&- || git -C '$(PHP_CONFIGURATION)' pull
	make -C '$(PHP_CONFIGURATION)' install
	git clone https://github.com/Fleshgrinder/php-fpm-sysvinit-script.git '$(PHP_FPM_INIT_SCRIPT)' 2>&- || git -C '$(PHP_FPM_INIT_SCRIPT)' pull
	make -C '$(PHP_FPM_INIT_SCRIPT)'
	sh $(CURDIR)/compile

uninstall-php:
	[ ! -d '$(PHP_CONFIGURATION)' ] || make -C '$(PHP_CONFIGURATION)' uninstall
	[ ! -d '$(PHP_FPM_INIT_SCRIPT)' ] || make -C '$(PHP_FPM_INIT_SCRIPT)' uninstall
	for BIN in $(shell which pear peardev pecl phar phar.phar php php-cgi php-config phpize php-fpm); do rm --force recursive -- "$${BIN}"; done
	rm --force --recursive -- '$(SRC_DIR)/php' '$(PHP_CONFIGURATION)' '$(PHP_FPM_INIT_SCRIPT)' /usr/local/lib/php /tmp/pear

composer:
	wget --quiet --output-document=- -- 'https://getcomposer.org/installer' | php
	install --mode=0755 --owner=root --group=root --verbose -- ./composer.phar '$(COMPOSER_BIN)'
	rm --force -- ./composer.phar

uninstall-composer:
	rm --force -- '$(COMPOSER_BIN)'
