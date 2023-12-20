FROM jrei/systemd-debian:12

RUN apt-get update && apt-get install -y ca-certificates

# build number from https://ci.mariadb.org/bb-11.4-pr2726-MDEV-19210-environment-file-pkgtest-latest-amd64-debian-12-deb-autobake.sources
# 
RUN echo "deb [trusted=yes] https://ci.mariadb.org/40904/amd64-debian-12-deb-autobake/debs ./" > /etc/apt/sources.list.d/mariadb.list
# from https://ci.mariadb.org/galera/mariadb-4.x-latest-gal-amd64-debian-12.sources
RUN echo "deb [trusted=yes] https://ci.mariadb.org/galera/mariadb-4.x/7dce5149980931f8360a3e1287e3da6a6b9e1cc7/gal-amd64-debian-12/debs ./" > /etc/apt/sources.list.d/galera.list
RUN apt-get update && apt-get install -y mariadb-server

COPY mariadb.cnf /etc/mysql/mariadb.conf.d/
VOLUME /var/lib/mysql
