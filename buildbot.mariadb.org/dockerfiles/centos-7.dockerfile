#
# Builbot worker for building MariaDB
#
# Provides a base CentOS image with latest buildbot worker installed

FROM       centos:7
MAINTAINER MariaDB Buildbot maintainers

USER root

# Install updates and required packages
RUN yum -y --enablerepo=extras install epel-release && \
    yum -y upgrade && \
    yum -y groupinstall 'Development Tools' && \
    yum -y install git ccache subversion \
    python-devel libffi-devel openssl-devel \
    python-pip redhat-rpm-config curl && \
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
RUN curl -Lo /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_amd64 && \
    chmod +x /usr/local/bin/dumb-init

USER buildbot
CMD ["/usr/local/bin/dumb-init", "twistd", "--pidfile=", "-ny", "buildbot.tac"]
