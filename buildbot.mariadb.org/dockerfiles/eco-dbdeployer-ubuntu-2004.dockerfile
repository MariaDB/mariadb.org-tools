FROM ubuntu:20.04

LABEL maintainer="MariaDB Buildbot maintainers"

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y make sudo curl libsnappy1v5 libaio1 vim-tiny perl-modules libnuma1 binutils \
        xz-utils wget less net-tools lsof libreadline5 python3-pip \
    && rm -rf /var/lib/apt/lists/* 

# Create buildbot user
RUN useradd -ms /bin/bash buildbot && \
    mkdir -p /buildbot && \
    chown -R buildbot /buildbot /usr/local && \
    curl -o /buildbot/buildbot.tac https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot.mariadb.org/dockerfiles/buildbot.tac

VOLUME /dbdeployer

WORKDIR /buildbot

# Upgrade pip and install packages
RUN pip3 install -U pip virtualenv
RUN pip3 install buildbot-worker && \
    pip3 --no-cache-dir install 'twisted[tls]'

RUN curl https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_$(dpkg --print-architecture).deb -Lo /tmp/init.deb && dpkg -i /tmp/init.deb

USER buildbot
ENV USER=buildbot
ENV HOME=/buildbot

CMD ["/usr/bin/dumb-init", "twistd", "--pidfile=", "-ny", "buildbot.tac"]

