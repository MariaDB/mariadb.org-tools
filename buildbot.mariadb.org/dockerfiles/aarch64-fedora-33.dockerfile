# Buildbot worker for building MariaDB
#
# Provides a base Fedora image with latest buildbot worker installed
# and MariaDB build dependencies

FROM       fedora:33
LABEL maintainer="MariaDB Buildbot maintainers"

# Install updates and required packages
RUN dnf -y upgrade && \
    dnf -y install @development-tools git wget ccache \
    subversion python-devel libffi-devel \
    openssl-devel python-pip redhat-rpm-config \
    dnf-plugins-core rpm-build && \
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

USER buildbot
CMD ["dumb-init", "twistd", "--pidfile=", "-ny", "buildbot.tac"]
