# Buildbot worker for building MariaDB
#
# Provides a base Fedora image with latest buildbot worker installed
# and MariaDB build dependencies

FROM       fedora:34
LABEL maintainer="MariaDB Buildbot maintainers"

# Install updates and required packages
RUN dnf -y upgrade && \
    dnf -y install @development-tools git wget ccache \
    subversion python-devel libffi-devel \
    openssl-devel python-pip redhat-rpm-config \
    dnf-plugins-core rpm-build liburing-devel && \
    # install MariaDB dependencies
    dnf -y builddep mariadb-server

# Create buildbot user
RUN useradd -ms /bin/bash buildbot && \
    mkdir /buildbot && \
    chown -R buildbot /buildbot && \
    curl -o /buildbot/buildbot.tac https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot.mariadb.org/dockerfiles/buildbot.tac
WORKDIR /buildbot

# upgrade pip and install buildbot
#    easy_install pip && \
#    pip install -U pip virtualenv && \
#    pip install --upgrade setuptools && \
RUN pip install buildbot-worker && \
    pip --no-cache-dir install 'twisted[tls]'

# Test runs produce a great quantity of dead grandchild processes.  In a
# non-docker environment, these are automatically reaped by init (process 1),
# so we need to simulate that here.  See https://github.com/Yelp/dumb-init
RUN curl -Lo /tmp/dumb.rpm http://rpmfind.net/linux/fedora/linux/releases/32/Everything/aarch64/os/Packages/d/dumb-init-1.2.2-6.fc32.aarch64.rpm && dnf -y localinstall /tmp/dumb.rpm

RUN dnf -y install cracklib cracklib-dicts cracklib-devel boost-devel curl-devel libxml2-devel lz4-devel snappy-devel check-devel scons
RUN dnf -y install Judy-devel binutils bison boost-devel checkpolicy coreutils cracklib-devel flex gawk gcc gcc-c++ git-core glibc-common glibc-devel groff-base java-latest-openjdk-devel java-latest-openjdk java-latest-openjdk-headless krb5-devel libaio-devel libcurl-devel libedit-devel libevent-devel libxcrypt-devel libxml2 libxml2-devel libzstd-devel lz4-devel make ncurses-devel openssl-devel pam-devel pcre2-devel pkgconf-pkg-config policycoreutils readline-devel rubypick snappy-devel systemd-devel systemtap-sdt-devel tar unixODBC unixODBC-devel xz-devel zlib-devel which python
RUN dnf -y install liburing-devel gdb

USER buildbot
CMD ["dumb-init", "twistd", "--pidfile=", "-ny", "buildbot.tac"]
