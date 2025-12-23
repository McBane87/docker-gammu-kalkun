ARG ENV_LC_ALL="C"
ARG ENV_DEBIAN_FRONTEND="noninteractive"
ARG ENV_TZ="Europe/London"
ARG ENV_LANG="en_GB.UTF-8"
ARG ENV_container="docker"
ARG IMAGE_PREFIX="amd64"

FROM --platform=linux/${IMAGE_PREFIX} debian:bookworm-slim as build

ARG ENV_LC_ALL
ENV LC_ALL=${ENV_LC_ALL}

ARG ENV_LANG
ENV LANG=${ENV_LANG}

ARG ENV_DEBIAN_FRONTEND
ENV DEBIAN_FRONTEND=${ENV_DEBIAN_FRONTEND}

ARG ENV_TZ
ENV TZ=${ENV_TZ}

ARG ENV_container
ENV container=${ENV_container}

ARG IMAGE_PREFIX
ENV IMAGE_PREFIX=${IMAGE_PREFIX}

ARG KALKUN_VER="v0.8.3.2"
ARG BUILD_PAK="curl wget git jq unzip lsb-release file dos2unix patch"
ARG SUPV_PAK="tzdata cron logrotate supervisor"
ARG MISC_PAK="ca-certificates locales rsync"
ARG APP_PAK_0="mariadb-server mariadb-client gammu gammu-smsd apache2"
ARG APP_PAK_82="php8.2 php8.2-mysql php8.2-mbstring php8.2-curl php8.2-intl php8.2-ldap php8.2-xml libapache2-mod-php8.2"
ARG APP_PAK_84="php8.4 php8.4-mysql php8.4-mbstring php8.4-curl php8.4-intl php8.4-ldap php8.4-xml libapache2-mod-php8.4"

# Crossbuild files
COPY arm/* /usr/bin/cross/arm/v7/
COPY aarch64/* /usr/bin/cross/arm64/v8/
COPY files/busybox-x86_64 /usr/bin/

# Change default shell to bash for building
RUN [ "/usr/bin/busybox-x86_64", "sh", "-c", "busybox-x86_64 cp -a /bin/sh /bin/sh.orig && busybox-x86_64 ln -sf /bin/bash /bin/sh"]

# Provide crossbuild files
RUN [ "/usr/bin/busybox-x86_64", "sh", "-c", "if [ ${IMAGE_PREFIX} != amd64 -a ${IMAGE_PREFIX} != 386 ]; then \
    busybox-x86_64 cp -av /usr/bin/cross/${IMAGE_PREFIX}/* /usr/bin/ && \
    busybox-x86_64 cp -a /bin/sh /bin/sh.real; fi"]

# Start crossbuild
RUN [ "/usr/bin/busybox-x86_64", "sh", "-c", "if [ ${IMAGE_PREFIX} != amd64 -a ${IMAGE_PREFIX} != 386 ]; then \
    cross-build-start; fi"]

# build files
COPY patches /var/run/patches

# production files
COPY files/selfsign.cnf /etc/ssl/
COPY files/selfsign.sh /etc/ssl/
COPY files/init.sh /sbin/init.sh
COPY files/00-docker-init.sh /etc/pre.systemd.d/
COPY files/sv-cron.conf /etc/supervisor/conf.d/cron.conf
COPY files/sv-mariadb.conf /etc/supervisor/conf.d/mariadb.conf
COPY files/sv-mariadb-post.conf /etc/supervisor/conf.d/mariadb-post.conf
COPY files/sv-gammu.conf /etc/supervisor/conf.d/gammu.conf
COPY files/sv-apache2.conf /etc/supervisor/conf.d/apache2.conf
COPY files/apache.conf /etc/apache2/conf-enabled/ZZ-custom.conf
COPY files/mariadb-post.sh /opt/mariadb-post.sh

# Install (build-) prerequisites
RUN \
    apt-get update && \
    apt-get install -y ${BUILD_PAK} ${MISC_PAK} && \
    if [ "$IMAGE_PREFIX" != "386" ]; then \
        wget -qO /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
        echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list \
    ;fi

# Install production packages
RUN \
    apt-get update && \
    apt-get install -y ${SUPV_PAK} ${MISC_PAK} ${APP_PAK_0} && \
    if [ "$IMAGE_PREFIX" == "386" ]; then \
        apt-get install -y ${APP_PAK_82} \
    ;else \
        apt-get install -y ${APP_PAK_84} \
    ;fi

# Install Gammu examples, which, for some reason, not get installed by default
RUN \
    mkdir /var/run/gammu-deb && chmod 777 /var/run/gammu-deb && cd /var/run/gammu-deb && \
    apt-get download -y gammu-smsd && dpkg -x *.deb . && \
    if [ ! -d /usr/share/doc/gammu-smsd/examples ]; then mkdir -p /usr/share/doc/gammu-smsd/examples; fi && \
    cp -a usr/share/doc/gammu-smsd/examples/mysql*.sql* /usr/share/doc/gammu-smsd/examples/

# Install Kalkun
RUN \
    wget -O /tmp/composer-setup.php https://getcomposer.org/installer && \
    php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    rm -f /tmp/composer-setup.php && \
    if [ -d /var/www ]; then rm -rf /var/www/*; fi && \
    git clone -b ${KALKUN_VER} https://github.com/kalkun-sms/Kalkun.git /var/www && \
    rm -rf /var/www/.git* && \
    cd /var/www && \
    jq 'del(.["require-dev"])' composer.json > composer_temp.json && mv composer_temp.json composer.json && \
    composer update --no-dev && composer install --no-dev && \
    find /var/www -type f -exec sh -c 'file -b "$1" | grep -q text && dos2unix "$1"' _ {} \; && \
    rm /var/www/install && \
    chown -R www-data:www-data /var/www

# Configure locales
RUN sed -i "/${ENV_LANG}/s/^# //g" /etc/locale.gen && locale-gen

# Configure Apache
RUN \
    mkdir /etc/apache2/ssl && \
    sed -i 's#/etc/ssl/certs/ssl-cert-snakeoil#/etc/apache2/ssl/selfsigned#g' /etc/apache2/sites-available/default-ssl.conf && \
    sed -i 's#/etc/ssl/private/ssl-cert-snakeoil#/etc/apache2/ssl/selfsigned#g' /etc/apache2/sites-available/default-ssl.conf && \
    ln -sf ../sites-available/default-ssl.conf /etc/apache2/sites-enabled/ && \
    ln -sf ../mods-available/ssl.{conf,load} /etc/apache2/mods-enabled/ && \
    ln -sf ../mods-available/socache_shmcb.load /etc/apache2/mods-enabled/

# Configure PHP
RUN \
    mkdir -m 775 /var/log/php && \
    chown -R root:www-data /var/log/php && \
    touch /var/log/php/error.log && \
    chown root:www-data /var/log/php/error.log && \
    chmod 664 /var/log/php/error.log && \
    echo -e "/var/log/php/error.log {\n  rotate 5\n  size 10M\n  compress\n  missingok\n  notifempty\n  create 664 root www-data}" > /etc/logrotate.d/php && \
    if [ "$IMAGE_PREFIX" == "386" ]; then \
        sed -i -e 's#^\s*;*error_log\s*=\s*php_errors.log.*$#error_log = /var/log/php/error.log#g' /etc/php/8.2/apache2/php.ini && \
        sed -i -e 's#^\s*;*error_log\s*=\s*php_errors.log.*$#error_log = /var/log/php/error.log#g' /etc/php/8.2/cli/php.ini \
    ;else \
        sed -i -e 's#^\s*;*error_log\s*=\s*php_errors.log.*$#error_log = /var/log/php/error.log#g' /etc/php/8.4/apache2/php.ini && \
        sed -i -e 's#^\s*;*error_log\s*=\s*php_errors.log.*$#error_log = /var/log/php/error.log#g' /etc/php/8.4/cli/php.ini \
    ;fi

# Configure Kalkun
RUN \
    cd /var/www && \
    for i in $(find /var/run/patches/ -maxdepth 1 -type f -name "*-kalkun-*.patch" | sort -n); do patch -p0 < $i || exit 1; done && \
    /bin/cp /var/run/patches/style/*.jpg /var/www/media/images/ && \
    /bin/cp /var/run/patches/style/*.png /var/www/media/images/ && \
    patch -p0 < /var/run/patches/style/style.patch && \
    mkdir /var/www/html && \
    mv index.php .htaccess media /var/www/html/ && \
    chown -R www-data:www-data /var/www

# Configure Gammu
RUN \
    mkdir /var/log/gammu-smsd && \
    cd /etc/ && for i in $(find /var/run/patches/ -maxdepth 1 -type f -name "*-gammu-*.patch" | sort -n); do patch -p0 < $i || exit 1; done && \
    echo -e "/var/log/gammu-smsd/gammu.log {\n  rotate 5\n  size 10M\n  compress\n  missingok\n  notifempty\n}" > /etc/logrotate.d/gammu-smsd

# Configure MariaDB
# (Better run after Gammu/Kalkun configure. Just in case we change something needed by database configure)
RUN \
    if [ ! -d /var/log/mysql ]; then mkdir /var/log/mysql && chown mysql:mysql /var/log/mysql; fi && \
    /usr/bin/supervisord -c /etc/supervisor/supervisord.conf && \
    supervisorctl start mariadb && \
    i=0 && while [ ! -S /run/mysqld/mysqld.sock -a $i -lt 10 ]; do i=$(($i+1)); sleep 1; done && \
    mysql -e 'CREATE DATABASE kalkun;' && \
    mysql kalkun < /usr/share/doc/gammu-smsd/examples/mysql.sql && \
    mysql kalkun < /var/www/application/sql/mysql/kalkun.sql && \
    mysql kalkun < /var/www/application/sql/mysql/pbk_gammu.sql && \
    mysql kalkun < /var/www/application/sql/mysql/pbk_kalkun.sql && \
    mysql kalkun <<< "INSERT INTO kalkun (version) VALUES ('$(sed 's/[^0-9.]//g' <<< ${KALKUN_VER#v})');" && \
    mysql -e "GRANT USAGE on *.* to 'gammu'@'localhost' IDENTIFIED BY 'MAlST101qfMy6FGYKj5d';" && \
    mysql -e "GRANT ALL PRIVILEGES on kalkun.* to 'gammu'@'localhost';" && \
    sleep 5 && supervisorctl stop mariadb && killall supervisord || true

# Enable supervisor services
RUN \
    find /etc/supervisor/conf.d/{cron,mariadb,mariadb-post,gammu,apache2}.conf | \
    xargs -n1 sed -i 's/autostart=false/autostart=true/g'

# Rearange directories for volume usage
RUN \
    mkdir /opt/{configs,logs,data} && \
    mkdir /opt/configs/kalkun && mkdir /etc/kalkun && \
    mv /var/www/application/config/config.php /etc/kalkun/config.php.dist && \
    mv /var/www/application/config/database.php /etc/kalkun/database.php.dist && \
    ln -s /opt/configs/kalkun/config.php /var/www/application/config/config.php && \
    ln -s /opt/configs/kalkun/database.php /var/www/application/config/database.php && \
    mv /etc/apache2 /etc/apache2.dist && \
    ln -s /opt/configs/apache2 /etc/apache2 && \
    mv /etc/mysql /etc/mysql.dist && \
    ln -s /opt/configs/mysql /etc/mysql && \
    mv /etc/gammu-smsdrc /etc/gammu-smsdrc.dist && \
    ln -s /opt/configs/gammu-smsdrc /etc/gammu-smsdrc && \
    mv /var/log/apache2 /var/log/apache2.dist && \
    ln -s /opt/logs/apache2 /var/log/apache2 && \
    mv /var/log/mysql /var/log/mysql.dist && \
    ln -s /opt/logs/mysql /var/log/mysql && \
    mv /var/log/gammu-smsd /var/log/gammu-smsd.dist && \
    ln -s /opt/logs/gammu-smsd /var/log/gammu-smsd && \
    mv /var/lib/mysql /var/lib/mysql.dist && \
    ln -s /opt/data/mysql /var/lib/mysql

# Cleanup
RUN \
    apt-get remove --purge -y ${BUILD_PAK} && \
    apt-get autoremove --purge -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    rm -rf /var/run/* && mkdir /var/run/lock

# End crossbuild
RUN [ "/usr/bin/busybox-x86_64", "sh", "-c", "if [ ${IMAGE_PREFIX} != amd64 -a ${IMAGE_PREFIX} != 386 ]; then \
    cross-build-end; fi"]

# Change default shell back to dist-default
RUN [ "/usr/bin/busybox-x86_64", "sh", "-c", "busybox-x86_64 mv /bin/sh.orig /bin/sh"]

# Cleanup crossbuild
RUN [ "/usr/bin/busybox-x86_64", "sh", "-c", \
    "busybox-x86_64 mv /bin/sh.real /bin/sh 2>/dev/null || true; \
    busybox-x86_64 rm -rf /usr/bin/cross /usr/bin/_qemu-* /usr/bin/qemu-* /usr/bin/cross-build-* /usr/bin/resin-xbuild /usr/bin/busybox-x86_64"]

FROM scratch

ARG ENV_LC_ALL
ENV LC_ALL=${ENV_LC_ALL}

ARG ENV_LANG
ENV LANG=${ENV_LANG}

ARG ENV_DEBIAN_FRONTEND
ENV DEBIAN_FRONTEND=${ENV_DEBIAN_FRONTEND}

ARG ENV_TZ
ENV TZ=${ENV_TZ}

ARG ENV_container
ENV container=${ENV_container}

COPY --from=build / /

VOLUME [ "/opt/configs" ]
VOLUME [ "/opt/data" ]
VOLUME [ "/opt/logs" ]

CMD ["/sbin/init.sh"]

EXPOSE 80
EXPOSE 443