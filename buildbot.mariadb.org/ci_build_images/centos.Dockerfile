# Buildbot worker for building MariaDB
#
# Provides a base CentOS image with latest buildbot worker installed
# and MariaDB build dependencies

ARG base_image
FROM "$base_image"
LABEL maintainer="MariaDB Buildbot maintainers"

# Install updates and required packages
RUN dnf -y --enablerepo=extras install epel-release \
    && dnf -y install 'dnf-command(config-manager)' \
    && dnf config-manager --set-enabled powertools \
    && dnf -y module enable mariadb-devel \
    && dnf -y upgrade \
    && dnf -y groupinstall "Development Tools" \
    && dnf -y builddep mariadb-server \
    && dnf -y install \
    # not sure if needed
    # perl \
    ccache \
    check-devel \
    cracklib-devel \
    curl-devel \
    java-1.8.0-openjdk \
    java-1.8.0-openjdk-devel \
    libcurl-devel \
    libevent-devel \
    libffi-devel \
    libxml2-devel \
    libzstd-devel \
    python3-devel \
    python3-scons \
    readline-devel \
    rpmlint \
    ruby \
    snappy-devel \
    subversion \
    unixODBC \
    unixODBC-devel \
    wget \
    xz-devel \
    yum-utils \
    && dnf clean all \
    # dumb-init rpm is not available on centos (official repo)
    && curl -sL "https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_$(uname -m)" >/usr/local/bin/dumb-init \
    && chmod +x /usr/local/bin/dumb-init \
    && case $(uname -m) in \
        "x86_64") curl -sL "https://github.com/tianon/gosu/releases/download/1.14/gosu-amd64" >/usr/local/bin/gosu ;; \
        "aarch64") curl -sL "https://github.com/tianon/gosu/releases/download/1.14/gosu-arm64" >/usr/local/bin/gosu ;; \
        "ppc64le") curl -sL "https://github.com/tianon/gosu/releases/download/1.14/gosu-ppc64el" >/usr/local/bin/gosu ;; \
    esac \
    && chmod +x /usr/local/bin/gosu

# install MariaDB dependencies
# see yum-builddep -y mariadb-server
# not sure this is needed:
# RUN wget http://yum.mariadb.org/10.5.6/centos8-amd64/srpms/MariaDB-10.5.6-1.el8.src.rpm
# RUN rpm -ivh ./MariaDB-10.5.6-1.el8.src.rpm
# RUN yum-builddep -y ~/rpmbuild/SPECS/*
