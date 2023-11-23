FROM quay.io/almalinuxorg/8-init

COPY *.repo /etc/yum.repos.d

RUN dnf install -y MariaDB-server

COPY mariadb.cnf /etc/my.cnf.d/
