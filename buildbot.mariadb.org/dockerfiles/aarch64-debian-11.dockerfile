#
# Buildbot worker for building MariaDB
#
# Provides a base Debian image with latest buildbot worker installed
# and MariaDB build dependencies

FROM       debian:bullseye
LABEL maintainer="MariaDB Buildbot maintainers"

# This will make apt-get install without question
ARG DEBIAN_FRONTEND=noninteractive

# Enable apt sources
RUN cat /etc/apt/sources.list | sed 's/^deb /deb-src /g' >> /etc/apt/sources.list

# Install updates and required packages
RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y build-dep -q mariadb-server && \
    apt-get -y install -q \
    apt-utils build-essential python-dev sudo git \
    devscripts equivs libcurl4-openssl-dev \
    ccache python3 python3-pip curl wget libssl-dev libzstd-dev \
    libevent-dev dpatch gawk gdb libboost-dev libcrack2-dev \
    libjudy-dev libnuma-dev libsnappy-dev libxml2-dev \
    unixodbc-dev uuid-dev fakeroot iputils-ping dh-exec libpcre2-dev \
    libarchive-dev libedit-dev liblz4-dev liburing-dev

# Create buildbot user
RUN useradd -ms /bin/bash buildbot && \
    mkdir /buildbot && \
    chown -R buildbot /buildbot && \
    curl -o /buildbot/buildbot.tac https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot.mariadb.org/dockerfiles/buildbot.tac
WORKDIR /buildbot

# autobake-deb will need sudo rights
RUN usermod -a -G sudo buildbot
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Upgrade pip and install packages
RUN pip3 install -U pip virtualenv
RUN pip3 install buildbot-worker && \
    pip3 --no-cache-dir install 'twisted[tls]'

# Test runs produce a great quantity of dead grandchild processes.  In a
# non-docker environment, these are automatically reaped by init (process 1),
# so we need to simulate that here.  See https://github.com/Yelp/dumb-init
RUN apt-get -y install dumb-init
RUN apt-get -y install debhelper libboost-all-dev check scons libboost-program-options-dev liburing-dev libpmem-dev

USER buildbot
CMD ["/usr/bin/dumb-init", "twistd", "--pidfile=", "-ny", "buildbot.tac"]
