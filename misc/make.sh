#!/bin/sh


OPENSHIFT_RUNTIME_DIR=$OPENSHIFT_HOMEDIR"app-root/runtime"
OPENSHIFT_REPO_DIR=$OPENSHIFT_HOMEDIR"app-root/runtime/repo"

echo "Start to Build"
# Exit on first error.
#set -e


# OpenShift sets GIT_DIR to . which terminates pull with an error:
# Not a git repository: '.'
#unset GIT_DIR

umask 077

# When using rockmongo this is set and can cause strange errors here
export PHPRC=${OPENSHIFT_RUNTIME_DIR}/etc/php5/

# Configure versions
NGINX_VERSION='1.5.1'
ZLIB_VERSION='1.2.8'
PCRE_VERSION='8.33'

PHP_VERSION='5.5.0'
ICU_VERSION='51.2'

LIBMCRYPT_VERSION='2.5.8'
LIBTOOL_VERSION='2.4.2'

NODE_VERSION='0.6.20' #'0.10.12'

declare -A PHP_PECL
declare -A PHP_PECL_CONFIGURE
PHP_PECL=( ["mongo"]='1.4.1' )
PHP_PECL_CONFIGURE=( )

# Setup dir references
ROOT_DIR=${OPENSHIFT_RUNTIME_DIR}
BUILD_DIR=${OPENSHIFT_TMP_DIR}"build"
export OPENSHIFT_RUN_DIR=${OPENSHIFT_RUNTIME_DIR}/run/
TEMPLATE_DIR=${OPENSHIFT_REPO_DIR}/misc/tmpl

# Load functions
source ${OPENSHIFT_REPO_DIR}/misc/build_nginx
source ${OPENSHIFT_REPO_DIR}/misc/build_php_libs
source ${OPENSHIFT_REPO_DIR}/misc/build_php
source ${OPENSHIFT_REPO_DIR}/misc/build_node

# Check nginx
check_nginx

# Check PHP
check_php

# Check pecl extensions
for ext in "${!PHP_PECL[@]}"; do
    check_pecl ${ext} ${PHP_PECL["$ext"]} ${PHP_PECL_CONFIGURE["$ext"]};
done

# Check NodeJS
check_node

echo "Start to Deploy"
NGINX_DIR=${OPENSHIFT_RUNTIME_DIR}/nginx/
PHP_DIR=${OPENSHIFT_RUNTIME_DIR}/php5/

mkdir -p ${BUILD_DIR}

echo "Pre-processing nginx config."
cp ${TEMPLATE_DIR}/nginx.conf.tmpl ${BUILD_DIR}/nginx.conf
perl -p -i -e 's/\$\{([^}]+)\}/defined $ENV{$1} ? $ENV{$1} : $&/eg' ${BUILD_DIR}/nginx.conf
cp ${BUILD_DIR}/nginx.conf ${NGINX_DIR}/conf/nginx.conf

echo "Pre-processing PHP-fpm config."
cp ${TEMPLATE_DIR}/php-fpm.conf.tmpl ${BUILD_DIR}/php-fpm.conf
perl -p -i -e 's/\$\{([^}]+)\}/defined $ENV{$1} ? $ENV{$1} : $&/eg' ${BUILD_DIR}/php-fpm.conf
cp ${BUILD_DIR}/php-fpm.conf ${PHP_DIR}/etc/php-fpm.conf

rm -rf ${BUILD_DIR}

bash_profile=${OPENSHIFT_DATA_DIR}/.bash_profile
echo "Copy bash profile."
cp ${TEMPLATE_DIR}/bash_profile.tmpl ${bash_profile}

echo "Starting nginx."
${OPENSHIFT_RUNTIME_DIR}/nginx/sbin/nginx

echo "Starting php-fpm."
${OPENSHIFT_RUNTIME_DIR}/php5/sbin/php-fpm

echo "Copy start stop action_hooks"
rm -rf ${OPENSHIFT_REPO_DIR}/.openshift/action_hooks
cp -rf ${OPENSHIFT_REPO_DIR}/misc/action_hooks ${OPENSHIFT_REPO_DIR}/.openshift/action_hooks

echo "**********************************"
echo "Every Thing has been done"
echo "**********************************"