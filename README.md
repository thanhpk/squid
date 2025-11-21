## Squid proxy server
- ready to to

This repo is based on: https://git.launchpad.net/~ubuntu-docker-images/ubuntu-docker-images/+git/squid/

### Usage
#### Docker
1. Login to your server (Example IP: `1.2.3.4`)
```sh
docker run -d --name squid-container -e SQUID_USER=user1 -e SQUID_PASS=s3cret -e TZ=UTC -p 3128:3128 thanhpk/squid:1.0.0
```

2. On your **local machine**
Check your local IP:
```sh
curl https://ipinfo.io/ip
```

Test if the server has hidden the IP
```sh
curl -x http://user1:123456@1.2.3.4:3128 https://ipinfo.io/ip
```

It should return `1.2.3.4` - the server IP instead of your local IP

#### Docker Compose

```yaml
name: dev
services:
  squid:
    image: thanhpk/squid:1.0.0
    container_name: squid-proxy
    ports:
      - "3128:3128"
    environment:
      - SQUID_USER=user1
      - SQUID_PASS=s3cret
    restart: unless-stopped
```

### Development
#### Build
```sh
docker build -t thanhpk/squid:1.0.0 .
```

#### Push
```sh
docker push thanhpk/squid:1.0.0
```
