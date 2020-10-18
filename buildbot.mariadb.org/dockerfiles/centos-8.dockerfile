#
# Builbot worker for building MariaDB
#
# Provides a base CentOS image with latest buildbot worker installed
# and MariaDB build dependencies

FROM       centos:8
LABEL maintainer="MariaDB Buildbot maintainers"

# Install updates and required packages
RUN yum -y --enablerepo=extras install epel-release && \
    yum -y upgrade && \
    yum -y install dnf-plugins-core && \
    yum config-manager --set-enabled PowerTools && \
    yum -y upgrade && \
    yum -y groupinstall 'Development Tools' && \
    yum -y install git ccache subversion yum-utils \
    python3-devel libffi-devel openssl-devel \
    python3-pip redhat-rpm-config curl wget

RUN wget http://yum.mariadb.org/10.5.6/centos8-amd64/srpms/MariaDB-10.5.6-1.el8.src.rpm
RUN rpm -ivh ./MariaDB-10.5.6-1.el8.src.rpm

# install MariaDB dependencies
#RUN curl -Lo judy-devel.rpm http://mirror.centos.org/centos/8/PowerTools/x86_64/os/Packages/Judy-devel-1.0.5-18.module_el8.1.0+217+4d875839.x86_64.rpm && yum -y localinstall judy-devel.rpm
RUN yum-builddep -y ~/rpmbuild/SPECS/*

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
RUN curl -Lo /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_amd64 && \
    chmod +x /usr/local/bin/dumb-init

RUN yum -y install perl-Memoize perl-Time-HiRes perl
RUN yum -y install cracklib cracklib-dicts

USER buildbot
CMD ["/usr/local/bin/dumb-init", "twistd", "--pidfile=", "-ny", "buildbot.tac"]

