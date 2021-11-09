# Buildbot worker for building MariaDB
#
# Provides a base RHEL-7 image with latest buildbot worker installed
# and MariaDB build dependencies

ARG base_image=rhel7
FROM registry.access.redhat.com/$base_image
LABEL maintainer="MariaDB Buildbot maintainers"

# Install updates and required packages
RUN --mount=type=secret,id=rhel_orgid,target=/run/secrets/rhel_orgid \
    --mount=type=secret,id=rhel_keyname,target=/run/secrets/rhel_keyname \
    subscription-manager register \
    --org="$(cat /run/secrets/rhel_orgid)" \
    --activationkey="$(cat /run/secrets/rhel_keyname)" \
    && rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
    && yum -y upgrade \
    && yum-builddep -y mariadb-server \
    && yum -y install \
    @development \
    boost-devel \
    ccache \
    check-devel \
    cracklib-devel \
    curl-devel \
    jemalloc-devel \
    libffi-devel \
    libxml2-devel \
    lz4-devel \
    python3-pip \
    scons \
    snappy-devel \
    wget \
    && yum clean all \
    && subscription-manager unregister \
    && curl -sL "https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_$(uname -m)" >/usr/local/bin/dumb-init \
    && chmod +x /usr/local/bin/dumb-init \
    && case $(uname -m) in \
        "x86_64") curl -sL "https://github.com/tianon/gosu/releases/download/1.14/gosu-amd64" >/usr/local/bin/gosu ;; \
        "aarch64") curl -sL "https://github.com/tianon/gosu/releases/download/1.14/gosu-arm64" >/usr/local/bin/gosu ;; \
        "ppc64le") curl -sL "https://github.com/tianon/gosu/releases/download/1.14/gosu-ppc64le" >/usr/local/bin/gosu ;; \
    esac \
    && chmod +x /usr/local/bin/gosu

ENV CRYPTOGRAPHY_ALLOW_OPENSSL_102=1

RUN curl -sO https://cmake.org/files/v3.19/cmake-3.19.0-Linux-x86_64.sh \
    && mkdir -p /opt/cmake \
    && sh cmake-3.19.0-Linux-x86_64.sh --prefix=/opt/cmake --skip-license \
    && ln -sf /opt/cmake/bin/cmake /usr/local/bin/cmake \
    && rm cmake-3.19.0-Linux-x86_64.sh

