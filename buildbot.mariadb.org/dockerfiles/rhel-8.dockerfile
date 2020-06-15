#
# Builbot worker for building MariaDB
#
# Provides a base RHEL-8 image with latest buildbot worker installed
# and MariaDB build dependencies

FROM       registry.access.redhat.com/ubi8/ubi
LABEL maintainer="MariaDB Buildbot maintainers"

RUN subscription-manager register --username %s --password %s --auto-attach

RUN subscription-manager repos --enable "codeready-builder-for-rhel-8-$(arch)-rpms"

RUN dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

# Install updates and required packages
RUN yum -y install epel-release && \
    yum -y upgrade && \
    yum -y groupinstall 'Development Tools' && \
    yum -y install git ccache subversion yum-utils \
    python3-devel libffi-devel openssl-devel \
    python3-pip redhat-rpm-config curl wget

# install MariaDB dependencies
RUN dnf -y install https://rpmfind.net/linux/fedora/linux/development/rawhide/Everything/x86_64/os/Packages/j/Judy-1.0.5-23.fc33.x86_64.rpm
RUN dnf -y install https://rpmfind.net/linux/fedora/linux/development/rawhide/Everything/x86_64/os/Packages/j/Judy-devel-1.0.5-23.fc33.x86_64.rpm
RUN yum-builddep -y mariadb-server

# Create buildbot user
RUN useradd -ms /bin/bash buildbot && \
    mkdir /buildbot && \
    chown -R buildbot /buildbot && \
    curl -o /buildbot/buildbot.tac https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot.mariadb.org/dockerfiles/buildbot.tac
WORKDIR /buildbot

# upgrade pip and install buildbot
RUN pip3 install -U pip virtualenv && \
    pip3 install --upgrade setuptools && \
    pip3 install buildbot-worker && \
    pip3 --no-cache-dir install 'twisted[tls]'

# Test runs produce a great quantity of dead grandchild processes.  In a
# non-docker environment, these are automatically reaped by init (process 1),
# so we need to simulate that here.  See https://github.com/Yelp/dumb-init
RUN curl -Lo /tmp/dumb.rpm https://cbs.centos.org/kojifiles/packages/dumb-init/1.1.3/17.el7/x86_64/dumb-init-1.1.3-17.el7.x86_64.rpm && yum -y localinstall /tmp/dumb.rpm

RUN subscription-manager unregister


USER buildbot
CMD ["dumb-init", "twistd", "--pidfile=", "-ny", "buildbot.tac"]
