#!/bin/bash

[[ -n $TZ ]] && \
    echo "[$(date +'%Y-%m-%d %H:%I:%S')] Setting timezone..." && \
    ln -sf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone

PHP_MODULE_CONF_CUR=$(find /etc/apache2/mods-available/ | grep -P '/php[0-9].*')
PHP_MODULE_CONF_DIST=$(find /etc/apache2.dist/mods-available/ | grep -P '/php[0-9].*')
if [[ "$PHP_MODULE_CONF_CUR" != "$PHP_MODULE_CONF_DIST" ]]; then
    echo "[$(date +'%Y-%m-%d %H:%I:%S')] Different PHP versions identified. Fixing ..."
    for i in $PHP_MODULE_CONF_CUR; do
        rm -vf "/etc/apache2/mods-enabled/$(basename "$i")"
    done

    rsync -a --ignore-existing /etc/apache2.dist/mods-available/ /etc/apache2/mods-available/
    for i in $PHP_MODULE_CONF_DIST; do
        ln -vrsf "/etc/apache2/mods-available/$(basename "$i")" "/etc/apache2/mods-enabled/"
    done
fi

if [ -d /etc/pre.systemd.d ]; then
    for i in /etc/pre.systemd.d/*.sh ; do
        if [ -r "$i" ]; then
                /bin/bash "$i"
        fi
    done
fi

echo "[$(date +'%Y-%m-%d %H:%I:%S')] Starting Supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf -n