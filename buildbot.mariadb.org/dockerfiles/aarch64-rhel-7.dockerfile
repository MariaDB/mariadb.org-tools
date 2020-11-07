#
# Builbot worker for building MariaDB
#
# Provides a base RHEL-7 image with latest buildbot worker installed
# and MariaDB build dependencies

FROM       registry.access.redhat.com/rhel7-aarch64
LABEL maintainer="MariaDB Buildbot maintainers"

RUN subscription-manager register --username %s --password %s --auto-attach

RUN rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
# Install updates and required packages
RUN yum -y install epel-release && \
    yum -y upgrade && \
    yum -y groupinstall 'Development Tools' && \
    yum -y install git ccache subversion \
    python-devel libffi-devel openssl-devel \
    python-pip redhat-rpm-config curl wget && \
    # install MariaDB dependencies
    yum-builddep -y mariadb-server

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
RUN curl -Lo /tmp/dumb.rpm https://cbs.centos.org/kojifiles/packages/dumb-init/1.1.3/17.el7/aarch64/dumb-init-1.1.3-17.el7.aarch64.rpm && yum -y localinstall /tmp/dumb.rpm

RUN subscription-manager unregister

ENV CRYPTOGRAPHY_ALLOW_OPENSSL_102=1

USER buildbot
CMD ["dumb-init", "twistd", "--pidfile=", "-ny", "buildbot.tac"]
