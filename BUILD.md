### For x86_64 / amd64
```sh
docker build --progress 'plain' -t 'kalkum-image' -f 'Dockerfile' .
```

### For x86 / i386
```sh
docker build --progress 'plain' -t 'kalkum-image' -f 'Dockerfile' --build-arg 'IMAGE_PREFIX=386' .
```

### For armhf / arm32v7
```sh
docker build --progress 'plain' -t 'kalkum-image' -f 'Dockerfile' --build-arg 'IMAGE_PREFIX=arm/v7' .
```

### For arm64 / aarch64
```sh
docker build --progress 'plain' -t 'kalkum-image' -f 'Dockerfile' --build-arg 'IMAGE_PREFIX=arm64/v8' .
```