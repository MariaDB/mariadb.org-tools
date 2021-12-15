# Buildbot worker for building MariaDB
#
# Provides a base Debian/Ubuntu image with latest buildbot worker installed
# and MariaDB build dependencies

ARG base_image
FROM "$base_image"
ARG mariadb_branch=10.5
LABEL maintainer="MariaDB Buildbot maintainers"

# This will make apt-get install without question
ARG DEBIAN_FRONTEND=noninteractive

# Enable apt sources
RUN if grep -q "ID=debian" /etc/os-release; then \
      cat /etc/apt/sources.list | sed 's/^deb /deb-src /g' >>/etc/apt/sources.list; \
    else \
      sed -i~orig -e 's/# deb-src/deb-src/' /etc/apt/sources.list; \
    fi

# Install updates and required packages
# see: https://cryptography.io/en/latest/installation/
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get -y install --no-install-recommends equivs devscripts curl \
    && curl -skO https://raw.githubusercontent.com/MariaDB/server/$mariadb_branch/debian/control \
    && mk-build-deps -r -i control \
    -t 'apt-get -y -o Debug::pkgProblemResolver=yes --no-install-recommends' \
    && apt-get -y build-dep -q mariadb-server \
    && apt-get -y install --no-install-recommends \
    build-essential \
    ccache \
    check \
    dpatch \
    dumb-init \
    gawk \
    git \
    gosu \
    iputils-ping \
    libasio-dev \
    libboost-dev \
    libboost-filesystem-dev \
    libboost-program-options-dev \
    libffi-dev \
    libssl-dev \
    python3-dev \
    python3-pip \
    python3-setuptools \
    scons \
    sudo  \
    wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

