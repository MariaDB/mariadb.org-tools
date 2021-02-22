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
    yum config-manager --set-enabled powertools && \
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

RUN yum -y install perl-Memoize perl-Time-HiRes perl
RUN yum -y install cracklib cracklib-dicts

RUN yum -y install cracklib cracklib-dicts cracklib-devel boost-devel curl-devel libxml2-devel lz4-devel snappy-devel check-devel python3-scons
RUN yum -y install binutils bison boost-devel checkpolicy coreutils cracklib-devel flex gawk gcc gcc-c++ git-core glibc-common glibc-devel groff-base java-1.8.0-openjdk-devel java-1.8.0-openjdk java-1.8.0-openjdk-headless krb5-devel libaio-devel libcurl-devel libevent-devel libxcrypt-devel libxml2 libxml2-devel libzstd-devel make ncurses-devel openssl-devel pam-devel pcre2-devel pkgconf-pkg-config policycoreutils readline-devel ruby snappy-devel systemd-devel systemtap-sdt-devel tar unixODBC unixODBC-devel xz-devel zlib-devel lz4-devel which --allowerasing

USER buildbot
CMD ["/usr/bin/dumb-init", "twistd", "--pidfile=", "-ny", "buildbot.tac"]
