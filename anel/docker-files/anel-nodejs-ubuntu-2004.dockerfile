# MDBI-57: Test nodejs connector
# Let's first to create a docker file that will do everything and after that we
# will split per buildbot needs.

FROM       ubuntu:20.04
LABEL maintainer="Anel Husakovic anel@mariadb.org"

ARG DEBIAN_FRONTEND=noninteractive

# Install updates and required packages (from ubuntu-2004.dockerfile)
# Enable apt sources
RUN sed -i~orig -e 's/# deb-src/deb-src/' /etc/apt/sources.list

RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y build-dep -q mariadb-server && \
    apt-get -y install -q \
    apt-utils build-essential python-dev sudo git \
    devscripts equivs libcurl4-openssl-dev flex \
    ccache python3 python3-pip curl wget libssl-dev libzstd-dev \
    libevent-dev dpatch gawk gdb libboost-dev libcrack2-dev \
    libjudy-dev libnuma-dev libsnappy-dev libxml2-dev \
    unixodbc-dev uuid-dev fakeroot iputils-ping dh-exec libpcre2-dev \
    libarchive-dev libedit-dev liblz4-dev dh-systemd flex libboost-atomic-dev \ 
    libboost-chrono-dev libboost-date-time-dev libboost-filesystem-dev \ 
    libboost-regex-dev libboost-system-dev libboost-thread-dev \
    gcc-10 g++-10

# Install nodejs and npm
RUN apt-get install -y nodejs && apt-get install -y npm

RUN mkdir /mysql-connector
WORKDIR /mysql-connector

RUN git clone https://github.com/mysqljs/mysql
WORKDIR ./mysql/test
RUN npm install -g n
# get the latest version of nodejs
RUN n latest && PATH="$PATH"

# Now we have to start the mariadb-server and run FILTER=unit npm test
# RUN mysqld ?

ADD ecofiles/test-nodejs.sh /
RUN chmod +x /test-nodejs.sh
CMD ["/test-nodejs.sh"]




# Additional test has been done on mariadb-connector see MDBI-57
# https://github.com/mariadb-corporation/mariadb-connector-nodejs
# Build image:
# $ docker build -f anel-nodejs-ubuntu-2004.dockerfile .
# Output
# REPOSITORY                           TAG                 IMAGE ID            CREATED             SIZE
# <none>                               <none>              9bde19cbff0a        3 seconds ago       1.43GB
# $ docker image rm IMAGE_ID IMAGE_ID
# But when changing to: $ docker build -t nodejs-anel -f anel-nodejs-ubuntu-2004.dockerfile .
# nodejs-anel                          latest              9bde19cbff0a        2 minutes ago       1.43GB



