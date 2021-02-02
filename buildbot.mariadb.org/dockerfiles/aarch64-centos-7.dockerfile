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
    python3-devel libffi-devel openssl-devel \
    python3-pip redhat-rpm-config curl wget && \
    # install MariaDB dependencies
    yum-builddep -y mariadb-server

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
RUN curl -Lo /tmp/dumb.rpm https://cbs.centos.org/kojifiles/packages/dumb-init/1.1.3/17.el7/aarch64/dumb-init-1.1.3-17.el7.aarch64.rpm && yum -y localinstall /tmp/dumb.rpm

RUN yum -y install cmake3

RUN alternatives --install /usr/local/bin/cmake cmake /usr/bin/cmake3 20 \
--slave /usr/local/bin/ctest ctest /usr/bin/ctest3 \
--slave /usr/local/bin/cpack cpack /usr/bin/cpack3 \
--slave /usr/local/bin/ccmake ccmake /usr/bin/ccmake3 \
--family cmake

RUN yum -y install cracklib cracklib-dicts cracklib-devel boost-devel curl-devel libxml2-devel lz4-devel snappy-devel check-devel scons
RUN yum -y install gnutls-devel systemd-devel
RUN yum -y install Judy-devel binutils bison boost-devel checkpolicy coreutils cracklib-devel gcc gcc-c++ git glibc-common glibc-devel groff-base java-1.8.0-openjdk-devel java-1.8.0-openjdk java-1.8.0-openjdk-headless krb5-devel libaio-devel libcurl-devel libevent-devel libxml2 libxml2-devel libzstd-devel make ncurses-devel openssl-devel pam-devel pcre2-devel pkgconfig policycoreutils-python readline-devel ruby snappy-devel systemd-devel systemtap-sdt-devel tar thrift-devel unixODBC unixODBC-devel xz-devel zlib-devel lz4-devel which
USER buildbot
CMD ["dumb-init", "twistd", "--pidfile=", "-ny", "buildbot.tac"]
