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
RUN dnf -y install https://kojipkgs.fedoraproject.org//packages/Judy/1.0.5/24.fc33/$(arch)/Judy-1.0.5-24.fc33.$(arch).rpm
RUN dnf -y install https://kojipkgs.fedoraproject.org//packages/Judy/1.0.5/24.fc33/$(arch)/Judy-devel-1.0.5-24.fc33.$(arch).rpm
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
RUN curl -Lo /tmp/dumb.rpm https://cbs.centos.org/kojifiles/packages/dumb-init/1.2.2/6.el8/$(arch)/dumb-init-1.2.2-6.el8.$(arch).rpm && yum -y localinstall /tmp/dumb.rpm

RUN dnf -y install cracklib cracklib-dicts cracklib-devel boost-devel curl-devel libxml2-devel lz4-devel snappy-devel check-devel python3-scons \
    judy-devel binutils bison boost-devel checkpolicy coreutils cracklib-devel gcc gcc-c++ git glibc-common glibc-devel groff-base java-1.8.0-openjdk \
    java-1.8.0-openjdk-headless krb5-devel libaio-devel libcurl-devel libevent-devel libxml2 libxml2-devel libzstd-devel make ncurses-devel \
    openssl-devel pam-devel pcre2-devel pkgconfig policycoreutils readline-devel ruby snappy-devel systemd-devel systemtap-sdt-devel tar unixODBC \
    unixODBC-devel xz-devel zlib-devel which python3 gdb jemalloc-devel --allowerasing && dnf clean all
RUN dnf -y install bzip2 lzo bzip2-libs bzip2-devel lzo-devel

RUN subscription-manager unregister

USER buildbot
CMD ["dumb-init", "twistd", "--pidfile=", "-ny", "buildbot.tac"]
