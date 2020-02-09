# docker-gammu-kalkun

```
docker create \
        --name gammu \
        --device  /dev/serial/by-id/<port_1>:/dev/ttyUSB0 \
        --device  /dev/serial/by-id/<port_2>:/dev/ttyUSB1 \
        --device  /dev/serial/by-id/<port_n>:/dev/ttyUSB2 \
        -e TZ=Europe/London \
        -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
        -v <SomePath>:/opt/configs \
        -v <SomePath>:/opt/website \
        -v <SomePath>:/opt/data \
        -v <SomePath>:/opt/logs \
        -p 80:80 \
        -p 443:443 \
        --tmpfs /run \
        --tmpfs /run/lock \
        --restart=always \
        gammu
 ```
