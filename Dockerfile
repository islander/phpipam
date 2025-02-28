FROM php:7.2-apache
MAINTAINER kiba <zombie32@gmail.com>

ENV PHPIPAM_SOURCE https://github.com/phpipam/phpipam/
ENV PHPIPAM_VERSION 1.4
ENV PHPMAILER_SOURCE https://github.com/PHPMailer/PHPMailer/
ENV PHPMAILER_VERSION 5.2.21
ENV PHPSAML_SOURCE https://github.com/onelogin/php-saml/
ENV PHPSAML_VERSION 2.10.6
ENV SECUREIMAGE_SOURCE https://github.com/dapphp/securimage/
ENV SECUREIMAGE_VERSION 3.6.7
ENV WEB_REPO /var/www/html

# Install required deb packages
RUN sed -i /etc/apt/sources.list -e 's/$/ non-free'/ && \
    apt-get update && apt-get -y upgrade && \
    rm /etc/apt/preferences.d/no-debian-php && \
    apt-get install -y libcurl4-gnutls-dev libgmp-dev libmcrypt-dev libfreetype6-dev libjpeg-dev libpng-dev libldap2-dev libsnmp-dev snmp-mibs-downloader iputils-ping locales && \
    rm -rf /var/lib/apt/lists/*

# Add russian language support
RUN locale-gen ru_RU.UTF-8 && \
    sed -i -e 's/# ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=ru_RU.UTF-8

# Configure apache and required PHP modules
RUN docker-php-ext-configure mysqli --with-mysqli=mysqlnd && \
    docker-php-ext-install mysqli && \
    docker-php-ext-configure gd --enable-gd-native-ttf --with-freetype-dir=/usr/include/freetype2 --with-png-dir=/usr/include --with-jpeg-dir=/usr/include && \
    docker-php-ext-install gd && \
    docker-php-ext-install curl && \
    docker-php-ext-install json && \
    docker-php-ext-install snmp && \
    docker-php-ext-install sockets && \
    docker-php-ext-install pdo_mysql && \
    docker-php-ext-install gettext && \
    ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h && \
    docker-php-ext-configure gmp --with-gmp=/usr/include/x86_64-linux-gnu && \
    docker-php-ext-install gmp && \
    docker-php-ext-install pcntl && \
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu && \
    docker-php-ext-install ldap && \
    pecl install mcrypt-1.0.1 && \
    docker-php-ext-enable mcrypt && \
    echo ". /etc/environment" >> /etc/apache2/envvars && \
    a2enmod rewrite

COPY php.ini /usr/local/etc/php/

# Copy phpipam sources to web dir
ADD ${PHPIPAM_SOURCE}/archive/${PHPIPAM_VERSION}.tar.gz /tmp/
RUN tar -xzf /tmp/${PHPIPAM_VERSION}.tar.gz -C ${WEB_REPO}/ --strip-components=1
# Copy referenced submodules into the right directory
ADD ${PHPMAILER_SOURCE}/archive/v${PHPMAILER_VERSION}.tar.gz /tmp/
RUN tar -xzf /tmp/v${PHPMAILER_VERSION}.tar.gz -C ${WEB_REPO}/functions/PHPMailer/ --strip-components=1
ADD ${PHPSAML_SOURCE}/archive/v${PHPSAML_VERSION}.tar.gz /tmp/
RUN tar -xzf /tmp/v${PHPSAML_VERSION}.tar.gz -C ${WEB_REPO}/functions/php-saml/ --strip-components=1
ADD ${SECUREIMAGE_SOURCE}/archive/${SECUREIMAGE_VERSION}.tar.gz /tmp/
RUN tar -xzf /tmp/${SECUREIMAGE_VERSION}.tar.gz -C ${WEB_REPO}/app/login/captcha/ --strip-components=1

# Use system environment variables into config.php
ENV PHPIPAM_BASE /
RUN cp ${WEB_REPO}/config.dist.php ${WEB_REPO}/config.php && \
    chown www-data /var/www/html/app/admin/import-export/upload && \
    chown www-data /var/www/html/app/subnets/import-subnet/upload && \
    chown www-data /var/www/html/css/images/logo && \
    echo "\$db['webhost'] = '%';" >> ${WEB_REPO}/config.php && \
    sed -i -e "s/\['host'\] = 'localhost'/\['host'\] = getenv(\"MYSQL_ENV_MYSQL_HOST\") ?: \"mysql\"/" \
    -e "s/\['user'\] = 'phpipam'/\['user'\] = getenv(\"MYSQL_ENV_MYSQL_USER\") ?: \"root\"/" \
    -e "s/\['name'\] = 'phpipam'/\['name'\] = getenv(\"MYSQL_ENV_MYSQL_DB\") ?: \"phpipam\"/" \
    -e "s/\['pass'\] = 'phpipamadmin'/\['pass'\] = getenv(\"MYSQL_ENV_MYSQL_ROOT_PASSWORD\")/" \
    -e "s/\['port'\] = 3306;/\['port'\] = 3306;\n\n\$password_file = getenv(\"MYSQL_ENV_MYSQL_PASSWORD_FILE\");\nif(file_exists(\$password_file))\n\$db\['pass'\] = preg_replace(\"\/\\\\s+\/\", \"\", file_get_contents(\$password_file));/" \
    -e "s/define('BASE', \"\/\")/define('BASE', getenv(\"PHPIPAM_BASE\"))/" \
    -e "s/\$gmaps_api_key.*/\$gmaps_api_key = getenv(\"GMAPS_API_KEY\") ?: \"\";/" \
    -e "s/\$gmaps_api_geocode_key.*/\$gmaps_api_geocode_key = getenv(\"GMAPS_API_GEOCODE_KEY\") ?: \"\";/" \
    ${WEB_REPO}/config.php

# Remove debug output (v1.4 only)
RUN sed -i '/var_dump/d' /var/www/html/app/footer.php

EXPOSE 80
