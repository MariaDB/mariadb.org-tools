# Buildbot worker for building MariaDB
#
# Provides a base Debian/Ubuntu image with latest buildbot worker installed
# and MariaDB build dependencies

ARG base_image
FROM "$base_image"
ARG mariadb_branch=10.7
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
    && apt-get -y install --no-install-recommends curl devscripts equivs lsb-release \
    && curl -skO https://raw.githubusercontent.com/MariaDB/server/$mariadb_branch/debian/control \
    && mkdir debian \
    && mv control debian/control \
    && touch debian/rules VERSION debian/not-installed \
    && curl -skO https://raw.githubusercontent.com/MariaDB/server/$mariadb_branch/debian/autobake-deb.sh \
    && chmod a+x autobake-deb.sh \
    && AUTOBAKE_PREP_CONTROL_RULES_ONLY=1 ./autobake-deb.sh \
    && mk-build-deps -r -i debian/control \
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
    # install Debian 9 only deps \
    && if grep -q 'stretch' /etc/apt/sources.list; then \
        apt-get -y install --no-install-recommends gnutls-dev; \
    fi \
    && apt-get clean
