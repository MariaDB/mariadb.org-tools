# Buildbot worker for building MariaDB
#
# Provides a base RHEL-7 image with latest buildbot worker installed
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
    && rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
    && yum -y upgrade \
    && yum-builddep -y mariadb-server \
    && yum -y install \
    @development \
    boost-devel \
    ccache \
    check-devel \
    cmake3 \
    cracklib-devel \
    curl-devel \
    jemalloc-devel \
    libffi-devel \
    libxml2-devel \
    lz4-devel \
    pcre2-devel \
    python3-pip \
    rpmlint \
    scons \
    snappy-devel \
    wget \
    && if [ "$(arch)" = "ppc64le" ]; then \
        subscription-manager repos --enable rhel-7-for-power-le-optional-rpms; \
        yum -y install python3-devel; \
    fi \
    && yum clean all \
    && subscription-manager unregister \
    # We can't use old cmake version (from @development package) \
    && yum -y remove cmake \
    && ln -sf /usr/bin/cmake3 /usr/bin/cmake \
    && curl -sL "https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_$(uname -m)" >/usr/local/bin/dumb-init \
    && chmod +x /usr/local/bin/dumb-init \
    && case $(uname -m) in \
        "x86_64") curl -sL "https://github.com/tianon/gosu/releases/download/1.14/gosu-amd64" >/usr/local/bin/gosu ;; \
        "aarch64") curl -sL "https://github.com/tianon/gosu/releases/download/1.14/gosu-arm64" >/usr/local/bin/gosu ;; \
        "ppc64le") curl -sL "https://github.com/tianon/gosu/releases/download/1.14/gosu-ppc64el" >/usr/local/bin/gosu ;; \
    esac \
    && chmod +x /usr/local/bin/gosu

ENV CRYPTOGRAPHY_ALLOW_OPENSSL_102=1
