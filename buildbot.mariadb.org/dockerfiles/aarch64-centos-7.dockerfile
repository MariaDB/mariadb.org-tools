#
# Builbot worker for building MariaDB
#
# Provides a base CentOS image with latest buildbot worker installed
# and MariaDB build dependencies

FROM       centos:7
LABEL maintainer="MariaDB Buildbot maintainers"

RUN sed '33s,baseurl=http://vault.centos.org/altarch/$releasever/extras/Source/,baseurl=http://mirror.centos.org/altarch/$releasever/extras/aarch64,g' -i /etc/yum.repos.d/CentOS-Sources.repo

# Install updates and required packages
RUN yum -y --enablerepo=extras install epel-release && \
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

USER buildbot
CMD ["dumb-init", "twistd", "--pidfile=", "-ny", "buildbot.tac"]
