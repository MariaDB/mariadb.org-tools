#
# Buildbot worker for building MariaDB
#
# Provides a base OpenSUSE image with latest buildbot worker installed
# and MariaDB build dependencies

FROM       opensuse/leap
LABEL maintainer="MariaDB Buildbot maintainers"

# Install updates and required packages
RUN zypper update -y && \
    zypper install -y -t pattern devel_basis && \
    zypper install -y git ccache subversion \
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

RUN zypper install -y boost-devel libboost_program_options1_66_0-devel libcurl-devel cracklib-devel libxml2-devel snappy-devel scons check-devel liblz4-devel
RUN zypper install -y binutils bison checkpolicy coreutils cracklib-devel flex gawk gcc gcc-c++ gcc7 git-core glibc glibc-devel groff java-1_8_0-openjdk java-1_8_0-openjdk-devel java-1_8_0-openjdk-headless judy-devel krb5-devel libaio-devel libboost_atomic1_66_0-devel libboost_chrono1_66_0-devel libboost_date_time1_66_0-devel libboost_filesystem1_66_0-devel libboost_headers1_66_0-devel libboost_regex1_66_0-devel libboost_system1_66_0-devel libboost_thread1_66_0-devel libbz2-devel libcurl-devel libevent-devel libfl-devel libopenssl-1_1-devel libxml2-devel libxml2-tools libzstd-devel lzo-devel make ncurses-devel pam-devel pcre2-devel pkg-config policycoreutils readline-devel snappy-devel systemd-devel tar unixODBC unixODBC-devel xz-devel zlib-devel binutils bison boost-devel checkpolicy coreutils cracklib-devel flex gawk gcc gcc-c++ git-core glibc glibc-devel groff java-1_8_0-openjdk java-1_8_0-openjdk-devel krb5-devel libaio-devel libbz2-devel libcurl-devel libevent-devel libopenssl-devel libxml2-devel libxml2-tools lzo-devel make ncurses-devel pam-devel pkg-config policycoreutils readline-devel ruby snappy-devel systemd-devel tar unixODBC unixODBC-devel xz-devel zlib-devel which

USER buildbot
CMD ["/usr/local/bin/dumb-init", "twistd", "--pidfile=", "-ny", "buildbot.tac"]
