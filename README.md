# docker-gammu-kalkun

This Docker image will provide gammu-smsd + apache2 + php + mariadb + kalkun.
So because it is based on supervisord and has all needed packages included at once, this image isn't lightweight. Expect 650MB - 750MB of disk space!

### Tags
|Tag|Architecture|
|-----|------------------|
|latest|amd64|
|latest-arm32v7|armhf|
|latest-arm64v8|arm64|

### HowTo build

Thanks to the awesome work of [balenalib](https://hub.docker.com/u/balenalib),
I was able to cross build this image for arm and aarch64.
This means, all builds are done using a x86_64 machine, but after build is done, they can be used on the target architechture.

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
        -v <SomePath>:/opt/configs \
        -v <SomePath>:/opt/data \
        -v <SomePath>:/opt/logs \
        -p 80:80 \
        -p 443:443 \
        --tmpfs /run \
        --tmpfs /run/lock \
        --restart=always \
        gammu
 ```

 Unfortunately the creation described above has a downside.
 If the device gets removed and reattched, then the container won't have access anymore and you are forced to restart the container.

 But there is a solution if you have a newer docker version.
 Instead of using `--device ...` you can have a look which major number your device is using.
 This can be done by doing this:
 ```
 ls -l /dev/serial/by-id/

 lrwxrwxrwx 1 root root 13 Feb 11 17:43 usb-ZTE-if00-port0 -> ../../ttyUSB0
 lrwxrwxrwx 1 root root 13 Feb 11 17:43 usb-ZTE-if01-port0 -> ../../ttyUSB2
 lrwxrwxrwx 1 root root 13 Feb 11 17:43 usb-ZTE-if02-port0 -> ../../ttyUSB3

 ls -l /dev/ttyUSB*

 crw-rw---- 1 root dialout 188, 0 Feb 11 17:43 /dev/ttyUSB0
 crw-rw---- 1 root dialout 188, 2 Feb 12 19:06 /dev/ttyUSB2
 crw-rw---- 1 root dialout 188, 3 Feb 11 17:43 /dev/ttyUSB3
 ```

 As you can see, the 3 devices of my modem are having the major number `188`.
 So I will now use the option `--device-cgroup-rule='c 188:* rmw'` to allow my container access the the devices.

 Additionally to this you need to find a way to keep your device files inside the docker uptodate.
 I've created a cronjob `vi /etc/crontab` (outside container!) for this:
 ```
 */1 *   * * *   root    mkdir -p  /dev/docker/gammu 2>/dev/null; for i in $(find /dev/serial/by-id/ -maxdepth 1 -mindepth 1 -type l -name "usb-ZTE-if*"); do /bin/cp -afu $(readlink -f $i) /dev/docker/gammu/$(basename $i) 2>/dev/null; done
 ```
 What the line above does, is the follwoing:
 * Create directory `/dev/docker/gammu` (we ignore already exists errors with `2>/dev/null`)
 * Find all files inside `/dev/serial/by-id/` with name `usb-ZTE-if*`
 * Follow symlink (`readlink -f`) for those files and copy them to `/dev/docker/gammu/` if there is a newer/updated file (the files copied will keep their symlink name, but won't be symlinks anymore)

 Also make sure to edit `/opt/config/gammu-smsdrc` (this is the path inside container, outside path depends on your choices) and update the `port = ttyUSB0` to match your new device name, which is accessable from inside container. (e.g.: `port = /dev/serial/by-id/usb-ZTE-if00-port0`)

 After all this is done we can create our docker container like this:

 ```
docker create \
        --name gammu \
        --device-cgroup-rule='c 188:* rmw' \
        -v /dev/docker/gammu:/dev/serial/by-id \
        -e TZ=Europe/London \
        -v <SomePath>:/opt/configs \
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

### Devices (--devices)
Here you have to pass your gsm-modem to your docker image. Many sticks provide more than one device. So you have to find out yourself which device is needed. By default gammu-smsd is looking for `/dev/ttyUSB0` inside the image. So you should pass the working device to this device inside. But you should also pass all the other devices to the docker image. Because I experienced unstable behaviour in my tests if I only passed one of the three devices....

### Security!
Change `encryption_key` in `/opt/configs/kalkun/config.php` to something else. If you don't do that, someone else with the same key maybe would be able to login to your website with his own kalkun cookie saved in his browser.

Change the password for mysql user gammu: `docker exec -it gammu mysql -e "ALTER USER 'gammu'@'localhost' IDENTIFIED BY '<NEWPASS>';"`
And update the files `/opt/configs/kalkun/database.php` and `/opt/configs/gammu-smsdrc` to match the new password.

Change the user inside the kalkun website. Because default is:
User: kalkun
Pass: kalkun

### API
If you want to send sms using the cli. You can use either a plugin like `jsonrpc` or you use the buildin API of kalkun. With a script I've added to the GIT in `other/send_sms.php`.

#### send_sms.php Example
`php send_sms.php -u kalkun -p kalkun -n +12345678 -m 'SomeMessage\nWith Newline' -H 'http://127.0.0.1/index.php/'`

#### jsonrpc Example
`curl -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","id":123,"method":"sms.send_sms", "params":{"user":"kalkun,"pass":"kalkun","phoneNumber":"+123456789","message":"Testing JSONRPC\nNewline"}}' http://127.0.0.1/index.php/plugin/jsonrpc/send_sms`

The `"id":123` can be a custom int or string. Also a word, for example. You decide.

If you don't specify an `id` key-value, which is possible, then the jsonrpc implementation thinks you don't want a response message. So I guess the `id` is meant for situations, when you send multiple sms and want to check which of them failed or succeeded by looking at the `id` in the response.
