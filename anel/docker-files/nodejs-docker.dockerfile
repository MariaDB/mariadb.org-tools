FROM node:15.3-buster
LABEL maintainer="anel@mariadb.org"
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get -y update
RUN apt-get -y upgrade
RUN apt-get install apt-utils dialog -y
RUN apt-get install build-essential -y

# MariaDB packages
VOLUME /packages

# Source code
VOLUME /code

RUN useradd -ms /bin/bash buildbot  && \
    mkdir -p /buildbot /data && \
    chown -R buildbot /buildbot /data /usr/local && \
    curl -o /buildbot/buildbot.tac https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot.mariadb.org/dockerfiles/buildbot.tac
WORKDIR /buildbot
