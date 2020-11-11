#
# Buildbot worker for building and running pymysql against mariadb server
#

FROM       python:3.9-slim-buster
LABEL maintainer="MariaDB Buildbot maintainers"

# This will make apt-get install without question
ARG DEBIAN_FRONTEND=noninteractive

# Install updates and required packages
RUN apt-get update -y && \
    apt-get install -y   \
      curl               \
      gcc                \
      git                \
      libaio1         && \
   rm -rf /var/lib/apt/lists/*

# MariaDB packages
VOLUME /packages

# Source code
VOLUME /code

# no /build required

# Create buildbot user
RUN useradd -ms /bin/bash buildbot && \
    mkdir /buildbot && \
    chown -R buildbot /buildbot /usr/local && \
    curl -o /buildbot/buildbot.tac https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot.mariadb.org/dockerfiles/buildbot.tac
WORKDIR /buildbot

# Upgrade pip and install packages
RUN pip3 install -U pip virtualenv
RUN pip3 install buildbot-worker && \
    pip3 --no-cache-dir install 'twisted[tls]' \
    cryptography \
    'PyNaCl>=1.4.0' \
    pytest

# https://github.com/PyMySQL/PyMySQL/blob/master/requirements-dev.txt

# Test runs produce a great quantity of dead grandchild processes.  In a
# non-docker environment, these are automatically reaped by init (process 1),
# so we need to simulate that here.  See https://github.com/Yelp/dumb-init
RUN curl https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_$(dpkg --print-architecture).deb -Lo /tmp/init.deb && dpkg -i /tmp/init.deb

USER buildbot
CMD ["/usr/bin/dumb-init", "twistd", "--pidfile=", "-ny", "buildbot.tac"]
