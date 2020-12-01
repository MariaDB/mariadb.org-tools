## MDBI-58: Ecosystem CI - nodejs
### How to?

Dockefiles used in order to build images withg specific dependencies using specific keywords/commands in the docker file.

#### Locally
As an example we are going to take a look on one of the existing docker files in [mariadb.org-tools](https://github.com/MariaDB/mariadb.org-tools/blob/master/buildbot.mariadb.org/dockerfiles/eco-pymysql-python-3-9-slim-buster.dockerfile) and learn new things.

1. Create directory and navigate
```
mkdir ~/mariadb
cd ~/mariadb/docker-files
```

2. Create a textfile file named `nodejs-worker.dockerfile`.

3. Use following in dockerfile
```
FROM node:15.3-buster
# visible from docker inspect
# MAINTAINER "Anel Husakovic" "anel@mariadb.org" not good use labels
LABEL maintainer="anel@mariadb.org"

RUN apt-get -y update
RUN apt-get -y upgrade
RUN apt-get install apt-utils dialog -y
RUN apt-get install build-essential -y

RUN mkdir /myvol
RUN echo "hello world" > /myvol/greeting
VOLUME /myvol

# No need for /packages and /code for bb branches
# MariaDB packages
VOLUME /packages

# Source code
VOLUME /code

RUN useradd -ms /bin/bash buildbot  && \
    mkdir -p /buildbot /data && \
    chown -R buildbot /buildbot /data /usr/local && \
    curl -o /buildbot/buildbot.tac https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot.mariadb.org/dockerfiles/buildbot.tac
WORKDIR /buildbot
```
- `FROM` command must be first (or `ARGS` or parser). It is using an image from dockerhub in this example from [node](https://hub.docker.com/_/node)
`node:latest` = `15.3.0 stretch` but we will use `buster`\
- `VOLUME` [link](https://docs.docker.com/engine/reference/builder/#volume) ^ mounting the create directory with data with `docker run -it <image>`, don't know how is visible to host?
   
   Note: it is not the same as `-v` option in `docker exec -it -v "$PWD"/host:/container`. Seems like `RUN mkdir` and `VOLUME` are the same.
   
   Note: [No need for /packages and /code for bb branches](https://github.com/MariaDB/mariadb.org-tools/blob/777b749f4551f87881170aef0bab0223c37fa93f/buildbot.mariadb.org/master.cfg#L195)

- `RUN useradd` is creating the new user `buildbot` with `home` directory (`-m`) and with the name of `shell` (`-s` option) as `/bin/bash`.
- Note that [master configuration](https://github.com/MariaDB/mariadb.org-tools/blob/777b749f4551f87881170aef0bab0223c37fa93f/buildbot.mariadb.org/master.cfg#L2807) has a commands for each step,
  that is invoking different scripts (found in [dockerfiles/ecofiles](https://github.com/MariaDB/mariadb.org-tools/tree/master/buildbot.mariadb.org/dockerfiles/ecofiles))
```
$ docker exec -it optimistic_wilson bash
root@e40656147920:/# ls -la|grep myvol 
drwxr-xr-x   2 root root 4096 Nov 26 10:48 myvol
```

4. Buid the image using `docker build` command which takes `options` and the `path` of a dockerfile. Specify `-t` (tag option) which allows to specify `<image-name>` and tag `<tag>`, `-f` filename of dockerfile `PATH/<dockerfile>` and a `PATH` as a current working directory:
```
$ docker build -t 'anel-nodejs-connector-image:ver1' -f ./nodejs-docker.dockerfile .
```

5. Inspect images with `docker images` and labels with `docker inspect`
```
$ docker images
REPOSITORY                           TAG                 IMAGE ID            CREATED             SIZE
anel-nodejs-connector-image          ver1                50578b10ed0a        50 seconds ago      929MB

$ docker inspect 50578b10ed0a
# or docker inspect anel-nodejs-connector-image:ver1 => json object with info
```
6. Create and run the container
```
$ docker run -it anel-nodejs-connector-image:ver1 bash
$ docker ps # user -a for all containers 
CONTAINER ID        IMAGE                              COMMAND                  CREATED             STATUS              PORTS               NAMES
e40656147920        anel-nodejs-connector-image:ver1   "docker-entrypoint.s…"   40 seconds ago      Up 39 seconds                           optimistic_wilson

```

7. Errors
```
Get:1 http://deb.debian.org/debian buster/main amd64 build-essential amd64 12.6 [7576 B]
debconf: delaying package configuration, since apt-utils is not installed
```
Add `apt-utils` before `build-essential`
```
Get:1 http://deb.debian.org/debian buster/main amd64 build-essential amd64 12.6 [7576 B]
debconf: unable to initialize frontend: Dialog
debconf: (TERM is not set, so the dialog frontend is not usable.)
debconf: falling back to frontend: Readline
debconf: unable to initialize frontend: Readline
debconf: (This frontend requires a controlling tty.)
debconf: falling back to frontend: Teletype
dpkg-preconfigure: unable to re-open stdin: 
```
Add `dialog` before `build-essential`
Even with ^ didn't suppress the errors.

*Question 1*

Adding `ARG DEBIAN_FRONTEND=noninteractive` suppressed but still says that `apt-utils` not installed ?

#### Literature

[Dockerfile reference](https://docs.docker.com/engine/reference/builder/)

[Example 1](https://thenewstack.io/docker-basics-how-to-use-dockerfiles/)
