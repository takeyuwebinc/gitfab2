gitfab2 [![Build Status](https://travis-ci.org/mozilla-japan/gitfab2.svg?branch=develop)](https://travis-ci.org/mozilla-japan/gitfab2) [![Code Climate](https://codeclimate.com/github/mozilla-japan/gitfab2/badges/gpa.svg)](https://codeclimate.com/github/mozilla-japan/gitfab2) [![Coverage Status](https://coveralls.io/repos/mozilla-japan/gitfab2/badge.svg?branch=develop&service=github)](https://coveralls.io/github/mozilla-japan/gitfab2?branch=develop)
=======

## Setup a build environment

### Requirements

- Docker 17 ce or later
- Docker Compose 1.16 or later

### Installation

```bash
$ git clone git@github.com:webdino/gitfab2.git
$ cd gitfab2
$ cp .env.sample .env
$ docker-compose build
```

### Open in Dev Container

1. Open in your VSCode
2. Open "Command Palette" (Ctrl + Shift + P)
2. Select "Dev Containers: Reopen in Container"

### Start Docker Compose

```bash
$ docker-compose up
$ docker-compose ps
    Name                   Command                  State               Ports         
--------------------------------------------------------------------------------------
gitfab2_app_1   prehook ruby -v bundle ins ...   Up             0.0.0.0:3000->3000/tcp
gitfab2_db_1    docker-entrypoint.sh --inn ...   Up (healthy)   3306/tcp
```

Open https://localhost:3000 in your browser.

#### Create database

```bash
$ docker-compose run app bundle exec rails db:setup
```

### Run tests

```bash
$ docker-compose run app bundle exec rails db:test:prepare
$ docker-compose run app bundle exec rspec
```

## Build Production Environment
### Edit Dockerfile.prod
Midify and run
```bash
$ vi config/Dockerfile.prod
$ docker build -t gitfab2 -f docker/Dockerfile.prod .
$ docker run -p 3000:3000 -e SECRET_KEY_BASE=xxxxxxxxxx gitfab2
```

## Deploy with Kamal (over SSH)
### Setup SSH
```bash
$ ssh-keygen -t ed25519
$ vi ~/.ssh/config
$ ssh gitfab2.host
```

```~/.ssh/config
Host  gitfab2.host
        HostName 123.456.789.012
        User deployuser
        Port 22
        IdentitiesOnly yes
        IdentityFile ~/.ssh/deployuser.deploy.id_ed25519
```

### Remote Host
#### Docker
```bash
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker deployuser
su deployuser
id
docker run hello-world
```

userns-remapを有効にする

```bash
vi /etc/docker/daemon.json
id deployuser
uid=1001(deployuser) gid=1001(deployuser) groups=1001(deployuser),100(users),988(docker)
vi /etc/subuid
vi /etc/subgid
systemctl restart docker
```

```json:/etc/docker/daemon.json
{
  "userns-remap": "deployuser"
}
```

```/etc/subuid
deployuser:1001:65536
```

```/etc/subgid
deployuser:1001:65536
```

#### postfix
```bash
apt-get install -y postfix
vi /etc/aliases
newaliases
vi /etc/postfix/main.cf
```

```
# mynetworks に追加 (Docker 172.0.0.0/8)
mynetworks = 127.0.0.0/8 172.0.0.0/8

# ローカルネットワークからの送信を認証なしにする、など
smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, defer_unauth_destination
```

#### rsyslog
```bash
apt-get install rsyslog
systemctl status rsyslog
mkdir /var/log/kamal
chown syslog:adm /var/log/kamal
chmod 750 /var/log/kamal
vi /etc/rsyslog.conf
vi /etc/rsyslog.d/00-kamal.conf
systemctl restart rsyslog
vi /etc/logrotate.d/kamal.conf
logrotate -f /etc/logrotate.d/kamal.conf
```

```/etc/rsyslog.conf
# provides UDP syslog reception
# 自分自身、ローカルネットワーク、Dockerネットワークからの接続を許可
module(load="imudp")
input(type="imudp" port="514")
$AllowedSender UDP, 127.0.0.1, 172.17.0.0/16, 172.18.0.0/16
```

```/etc/rsyslog.d/00-kamal.conf
:programname, contains, "web" /var/log/kamal/web.log
&stop
:programname, contains, "job" /var/log/kamal/job.log
&stop
:programname, contains, "cron" /var/log/kamal/cron.log
&stop
:programname, contains, "db" /var/log/kamal/db.log
&stop
:programname, contains, "proxy" /var/log/kamal/proxy.log
&stop
```

```/etc/logrotate.d/kamal.conf
/var/log/kamal/*.log {
        rotate 180
        daily
        missingok
        notifempty
        compress
        delaycompress
        create 0640 syslog adm
        sharedscripts
        postrotate
                /usr/lib/rsyslog/rsyslog-rotate
        endscript
}
```

### Install Kamal
Gemfile の development グループに記載されているため、別途インストールは不要

```bash
$ bundle install
$ kamal version
$ bundle exec kamal version
```

### Configuration
```bash
$ cp .kamal/secrets-common.sample .kamal/secrets-common
$ vi .kamal/secrets-common
$ cp config/deploy.production.yml.sample config/deploy.production.yml
$ vi config/deploy.production.yml
```

```yml:config/deploy.production.yml
image: your-dockerhub-username/gitfab2
registry:
  username: your-dockerhub-username
servers:
  web:
    hosts:
      - 123.456.789.012
  job:
    hosts:
      - 123.456.789.012
  cron:
    hosts:
      - 123.456.789.012
proxy:
  ssl: true
  host: gitfab2.host
ssh:
  user: deployuser
  port: 22
accessories:
  db:
    host: 123.456.789.012
```

### Deploy
アクセサリ（MySQL）を起動

```bash
$ bundle exec kamal accessory boot all -d production
```

アプリをデプロイ

```bash
$ bundle exec kamal deploy -d production
```

## License

gitfab2 is released under the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).

Copyright 2017 WebDINO Japan.
