# Buildbot worker for building MariaDB
#
# Provides a base OpenSUSE image with latest buildbot worker installed
# and MariaDB build dependencies

FROM registry.suse.com/suse/sles12sp5
LABEL maintainer="MariaDB Buildbot maintainers"

ENV ADDITIONAL_MODULES sle-module-development-tools,PackageHub,sle-sdk

RUN zypper --gpg-auto-import-keys ref -s

#ADD *.repo /etc/zypp/repos.d/
#ADD *.service /etc/zypp/services.d/
#RUN zypper -n --no-gpg-checks refs && zypper -n --no-gpg-checks refresh

RUN zypper --non-interactive --no-gpg-checks addrepo https://download.opensuse.org/repositories/devel:tools:building/SLE_12/devel:tools:building.repo
RUN zypper --non-interactive --no-gpg-checks addrepo https://download.opensuse.org/repositories/server:monitoring/SLE_12_SP4/server:monitoring.repo
RUN zypper --non-interactive --no-gpg-checks addrepo https://download.opensuse.org/repositories/Cloud:Tools/SLE_12_SP4/Cloud:Tools.repo

RUN zypper --non-interactive --no-gpg-checks refresh

# Install updates and required packages
RUN zypper update -y && \
    #zypper install -y -t pattern Basis_devel && \
    zypper install -y git-core ccache \
    python-devel libffi-devel openssl-devel glibc-locale\
    python-pip curl wget && \
    # install MariaDB dependencies
    #zypper mr -er repo-source
    zypper -n si -d mariadb

# Create buildbot user
RUN useradd -ms /bin/bash buildbot && \
    mkdir /buildbot && \
    chown -R buildbot /buildbot && \
    curl -o /buildbot/buildbot.tac https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot.mariadb.org/dockerfiles/buildbot.tac
WORKDIR /buildbot

# upgrade pip and install buildbot
RUN pip install -U pip virtualenv && \
    pip install --upgrade setuptools && \
    pip install buildbot-worker && \
    pip --no-cache-dir install 'twisted[tls]'

# Test runs produce a great quantity of dead grandchild processes.  In a
# non-docker environment, these are automatically reaped by init (process 1),
# so we need to simulate that here.  See https://github.com/Yelp/dumb-init
RUN curl -Lo /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_amd64 && \
    chmod +x /usr/local/bin/dumb-init

RUN zypper install -y policycoreutils rpm-build

RUN wget https://cmake.org/files/v3.19/cmake-3.19.0-Linux-x86_64.sh
RUN mkdir -p /opt/cmake
RUN sh cmake-3.19.0-Linux-x86_64.sh --prefix=/opt/cmake --skip-license
RUN ln -sf /opt/cmake/bin/cmake /usr/local/bin/cmake

RUN zypper install -y boost-devel libcurl-devel cracklib-devel libxml2-devel snappy-devel scons check-devel liblz4-devel

USER buildbot
CMD ["/usr/local/bin/dumb-init", "twistd", "--pidfile=", "-ny", "buildbot.tac"]
