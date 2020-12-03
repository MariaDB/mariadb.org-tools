#
# Buildbot worker for building and running PHP against mariadb server
#
# Provides a base Ubuntu image with latest buildbot worker installed
# and PHP build dependencies

FROM       ubuntu:20.04
LABEL maintainer="MariaDB Buildbot maintainers"

ARG DEBIAN_FRONTEND=noninteractive

# libaio1, snappy/numa is for the mariadb tarall
# libreadline5 for mariadb client
# curl, git used in intialization, rest are
# for php.
RUN apt-get update -y && \
    apt-get install -y \
      libaio1              \
      libsnappy1v5 libnuma1 wget libreadline5 \
      python3 python3-pip  \
      curl                 \
      language-pack-de     \
      libgmp-dev           \
      libicu-dev           \
      libtidy-dev          \
      libenchant-dev       \
      libaspell-dev        \
      libpspell-dev        \
      librecode-dev        \
      libsasl2-dev         \
      libxpm-dev           \
      libzip-dev           \
      git                  \
      pkg-config           \
      build-essential      \
      autoconf             \
      bison                \
      re2c                 \
      libxml2-dev          \
      libsqlite3-dev       \
      libmysqlclient-dev   && \
   rm -rf /var/lib/apt/lists/*

# Create buildbot user
RUN useradd -ms /bin/bash buildbot && \
    mkdir -p /buildbot /data && \
    chown -R buildbot /buildbot /data /usr/local && \
    curl -o /buildbot/buildbot.tac https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot.mariadb.org/dockerfiles/buildbot.tac

# Hope to eventualy move away from needing sudo rights
RUN usermod -a -G sudo buildbot
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

WORKDIR /buildbot

# Upgrade pip and install packages
RUN pip3 install -U pip virtualenv
RUN pip3 install buildbot-worker && \
    pip3 --no-cache-dir install 'twisted[tls]'

# Test runs produce a great quantity of dead grandchild processes.  In a
# non-docker environment, these are automatically reaped by init (process 1),
# so we need to simulate that here.  See https://github.com/Yelp/dumb-init
RUN curl https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_$(dpkg --print-architecture).deb -Lo /tmp/init.deb && dpkg -i /tmp/init.deb

CMD ["/usr/bin/dumb-init", "twistd", "--pidfile=", "-ny", "buildbot.tac"]
