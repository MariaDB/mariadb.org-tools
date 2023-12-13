FROM mariadb:lts
RUN apt-get update && apt-get install -y mariadb-plugin-spider && rm -rf /var/lib/apt/lists/* /etc/mysql/mariadb.conf.d/spider.cnf
COPY init/init_srv.sh /docker-entrypoint-initdb.d/
