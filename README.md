# docker-gammu-kalkun

This Docker image will provide gammu-smsd + apache2 + php5.6 + mysql + kalkun + systemd + some others.  
So because it is based on systemd and has all needed packages included at once, this image isn't lightweight. Expect 900MB - 1000MB of disk space!

### HowTo build

Thanks to the awesome work of [balenalib](https://hub.docker.com/u/balenalib),  
I was able to cross build this image for arm and aarch64.  
This means, all build are done using a x86_64 machine, but after build can be run on target architechture.

```
docker build \
        -t gammu . \
        -f Dockerfile
```

### HowTo create
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

### Environment
| Variable      | Default       | Description                                |
| ------------- |:-------------:| ------------------------------------------ |
| TZ            | Europe/London | The timezone to use.                       |

### Volumes
| Volume        | Description                                |
| ------------- |------------------------------------------|
| /opt/configs  | Path where all the configs can be found.|
| /opt/data     | Path where data can be found. Currently only mysql database files.  |
| /opt/logs     | Path for logfiles |
| /opt/website  | All Website files. |

### Devices (--devices)
Here you have to pass your gsm-modem to your docker image. Many sticks provide more than one device. So you have to find out yourself which device is needed. By default gammu-smsd is looking for `/dev/ttyUSB0` inside the image. So you should pass the working device to this device inside. But you should also pass all the other devices to the docker image. Because I experienced unstable behaviour in my tests if I only passed one of the three devices....

### Misc things to do
