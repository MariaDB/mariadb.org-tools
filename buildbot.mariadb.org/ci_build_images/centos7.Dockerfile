# Buildbot worker for building MariaDB
#
# Provides a base CentOS image with latest buildbot worker installed
# and MariaDB build dependencies

ARG base_image
FROM "$base_image"
LABEL maintainer="MariaDB Buildbot maintainers"

# Install updates and required packages
RUN yum -y --enablerepo=extras install epel-release \
    && sed -i '/baseurl/s/^#//g' /etc/yum.repos.d/epel.repo \
    && sed -i '/metalink/s/^/#/g' /etc/yum.repos.d/epel.repo \
    && yum -y upgrade \
    && yum -y groupinstall 'Development Tools' \
    && yum-builddep -y mariadb-server \
    && yum -y install \
    Judy-devel \
    boost-devel \
    ccache \
    check-devel \
    cmake3 \
    cracklib-devel \
    curl-devel \
    gnutls-devel \
    java-1.8.0-openjdk \
    java-1.8.0-openjdk-devel \
    java-1.8.0-openjdk-headless \
    jemalloc-devel \
    libcurl-devel \
    libevent-devel \
    libffi-devel \
    libxml2-devel \
    libzstd-devel \
    lz4-devel \
    pcre2-devel \
    python3 \
    python3-pip \
    rpmlint \
    ruby \
    scons \
    snappy-devel \
    systemd-devel \
    unixODBC \
    unixODBC-devel \
    wget \
    which \
    xz-devel \
    && yum clean all \
    && alternatives --install /usr/local/bin/cmake cmake /usr/bin/cmake3 20 \
    --slave /usr/local/bin/ctest ctest /usr/bin/ctest3 \
    --slave /usr/local/bin/cpack cpack /usr/bin/cpack3 \
    --slave /usr/local/bin/ccmake ccmake /usr/bin/ccmake3 \
    --family cmake \
    # dumb-init rpm is not available on centos
    && curl -sL "https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_$(uname -m)" >/usr/local/bin/dumb-init \
    && chmod +x /usr/local/bin/dumb-init \
    && case $(uname -m) in \
        "x86_64") curl -sL "https://github.com/tianon/gosu/releases/download/1.14/gosu-amd64" >/usr/local/bin/gosu ;; \
        "aarch64") curl -sL "https://github.com/tianon/gosu/releases/download/1.14/gosu-arm64" >/usr/local/bin/gosu ;; \
        "ppc64le") curl -sL "https://github.com/tianon/gosu/releases/download/1.14/gosu-ppc64el" >/usr/local/bin/gosu ;; \
    esac \
    && chmod +x /usr/local/bin/gosu
