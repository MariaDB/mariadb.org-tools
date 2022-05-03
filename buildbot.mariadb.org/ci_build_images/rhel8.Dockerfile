# Builbot worker for building MariaDB
#
# Provides a base RHEL-8 image with latest buildbot worker installed
# and MariaDB build dependencies

ARG base_image
FROM registry.access.redhat.com/$base_image
LABEL maintainer="MariaDB Buildbot maintainers"

# Install updates and required packages
RUN --mount=type=secret,id=rhel_orgid,target=/run/secrets/rhel_orgid \
    --mount=type=secret,id=rhel_keyname,target=/run/secrets/rhel_keyname \
    subscription-manager register \
    --org="$(cat /run/secrets/rhel_orgid)" \
    --activationkey="$(cat /run/secrets/rhel_keyname)" \
    && subscription-manager repos --enable "codeready-builder-for-rhel-8-$(uname -m)-rpms" \
    && rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm \
    && dnf -y upgrade \
    && dnf -y groupinstall "Development Tools" \
    && dnf -y install \
    "https://kojipkgs.fedoraproject.org/packages/Judy/1.0.5/25.fc34/$(arch)/Judy-1.0.5-25.fc34.$(arch).rpm" \
    "https://kojipkgs.fedoraproject.org/packages/Judy/1.0.5/25.fc34/$(arch)/Judy-devel-1.0.5-25.fc34.$(arch).rpm" \
    && dnf -y builddep mariadb-server \
    && dnf -y install \
    boost-devel \
    ccache \
    check-devel \
    checkpolicy \
    coreutils \
    cracklib-devel \
    curl-devel \
    # fmt-devel # >= 7.0 needed, epel8 has 6.2.1-1.el8
    java-1.8.0-openjdk \
    jemalloc-devel --allowerasing \
    krb5-devel \
    libaio-devel \
    libcurl-devel \
    libevent-devel \
    libffi-devel \
    liburing-devel \
    libxml2-devel \
    libzstd-devel \
    lz4-devel \
    ncurses-devel \
    openssl-devel \
    pam-devel \
    pcre2-devel \
    pkgconfig \
    policycoreutils \
    python3 \
    python3-devel \
    python3-scons \
    readline-devel \
    rpmlint \
    ruby \
    snappy-devel \
    subversion \
    systemd-devel \
    systemtap-sdt-devel \
    unixODBC \
    unixODBC-devel \
    wget \
    xz-devel \
    yum-utils \
    && dnf clean all \
    && subscription-manager unregister \
    # dumb-init rpm is not available on rhel \
    && curl -sL "https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_$(uname -m)" >/usr/local/bin/dumb-init \
    && chmod +x /usr/local/bin/dumb-init \
    && case $(uname -m) in \
        "x86_64") curl -sL "https://github.com/tianon/gosu/releases/download/1.14/gosu-amd64" >/usr/local/bin/gosu ;; \
        "aarch64") curl -sL "https://github.com/tianon/gosu/releases/download/1.14/gosu-arm64" >/usr/local/bin/gosu ;; \
        "ppc64le") curl -sL "https://github.com/tianon/gosu/releases/download/1.14/gosu-ppc64el" >/usr/local/bin/gosu ;; \
    esac \
    && chmod +x /usr/local/bin/gosu
