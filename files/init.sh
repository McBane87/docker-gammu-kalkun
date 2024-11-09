#!/bin/bash

[[ -n $TZ ]] && \
    echo "[$(date +'%Y-%m-%d %H:%I:%S')] Setting timezone..." && \
    ln -sf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone

if [ -d /etc/pre.systemd.d ]; then
    for i in /etc/pre.systemd.d/*.sh ; do
        if [ -r "$i" ]; then
                /bin/bash "$i"
        fi
    done
fi

echo "[$(date +'%Y-%m-%d %H:%I:%S')] Starting Supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf -n