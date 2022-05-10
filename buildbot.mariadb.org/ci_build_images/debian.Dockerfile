# Buildbot worker for building MariaDB
#
# Provides a base Debian/Ubuntu image with latest buildbot worker installed
# and MariaDB build dependencies

ARG base_image
FROM "$base_image"
ARG mariadb_branch=10.7
LABEL maintainer="MariaDB Buildbot maintainers"
ENV CARGO_NET_GIT_FETCH_WITH_CLI=true

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
    && apt-get -y install --no-install-recommends curl devscripts equivs \
    && curl -skO https://raw.githubusercontent.com/MariaDB/server/$mariadb_branch/debian/control \
    # MDEV-27965 - temporary hack to introduce a late libfmt dependency, so \
    # the main branches don't immediately fail on autobake builders once \
    # https://github.com/MariaDB/server/pull/2062 is merged. \
    && sed -i -e '/libedit-dev:native/a\\               libfmt-dev (>= 7.0.0),' control \
    # skip unavailable deps on Debian 9 \
    && if grep -q 'stretch' /etc/apt/sources.list; then \
        sed '/libfmt-dev/d' -i control; \
        sed '/libpmem-dev/d' -i control; \
        sed '/liburing-dev/d' -i control; \
        sed '/libzstd-dev/d' -i control; \
    fi \
    # skip unavailable deps on Debian 10 \
    && if grep -q 'buster' /etc/apt/sources.list; then \
        # libpmem-dev is not available on buster ARM/PPC \
        if [ "$(uname -m)" != "x86_64" ]; then \
            sed '/libpmem-dev/d' -i control; \
        fi; \
        sed '/libfmt-dev/d' -i control; \
        sed '/liburing-dev/d' -i control; \
    fi \
    # skip unavailable deps on Ubuntu 18.04 \
    && if grep -q 'bionic' /etc/apt/sources.list; then \
        sed '/libfmt-dev/d' -i control; \
        sed '/libpmem-dev/d' -i control; \
        sed '/liburing-dev/d' -i control; \
    fi \
    # skip unavailable deps on Ubuntu 20.04 \
    && if grep -q 'focal' /etc/apt/sources.list; then \
        sed '/libfmt-dev/d' -i control; \
        sed '/liburing-dev/d' -i control; \
    fi \
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
    # install Debian 9 only deps \
    && if grep -q 'stretch' /etc/apt/sources.list; then \
        apt-get -y install --no-install-recommends gnutls-dev; \
    fi \
    && apt-get clean
