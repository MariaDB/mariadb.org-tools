# Buildbot worker for building MariaDB
#
# Provides a base Fedora image with latest buildbot worker installed
# and MariaDB build dependencies

ARG base_image
FROM "$base_image"
LABEL maintainer="MariaDB Buildbot maintainers"

# Install updates and required packages
RUN dnf -y upgrade \
    && dnf -y install 'dnf-command(builddep)' \
    && dnf -y builddep mariadb-server \
    && dnf -y install \
    @development-tools \
    bzip2 \
    bzip2-devel \
    bzip2-libs \
    ccache \
    check-devel \
    curl-devel \
    dumb-init \
    flex \
    fmt-devel \
    java-latest-openjdk \
    java-latest-openjdk-devel \
    java-latest-openjdk-headless \
    jemalloc-devel \
    libcurl-devel \
    libevent-devel \
    libffi-devel \
    liburing-devel \
    lzo \
    lzo-devel \
    python-unversioned-command \
    python3-devel \
    python3-pip \
    readline-devel \
    rpm-build \
    rpmlint \
    rubypick \
    scons \
    snappy-devel \
    unixODBC \
    unixODBC-devel \
    wget \
    && if [ "$(uname -m)" = "x86_64" ]; then dnf -y install libpmem-devel; fi \
    && dnf clean all \
    && case $(uname -m) in \
        "x86_64") curl -sL "https://github.com/tianon/gosu/releases/download/1.14/gosu-amd64" >/usr/local/bin/gosu ;; \
        "aarch64") curl -sL "https://github.com/tianon/gosu/releases/download/1.14/gosu-arm64" >/usr/local/bin/gosu ;; \
        "ppc64le") curl -sL "https://github.com/tianon/gosu/releases/download/1.14/gosu-ppc64el" >/usr/local/bin/gosu ;; \
    esac \
    && chmod +x /usr/local/bin/gosu
