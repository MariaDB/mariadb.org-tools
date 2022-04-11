FROM mariadb:latest
LABEL maintainer="anel@mariadb.org"
RUN apt-get -y update && \
    apt-get install mariadb-plugin-connect -y && \
    rm -rf /var/lib/apt/lists/*
