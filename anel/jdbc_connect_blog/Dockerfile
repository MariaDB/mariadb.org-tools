ARG mariadb_version=latest
FROM "mariadb:$mariadb_version"

RUN apt-get update && \
    apt install openjdk-11-jdk-headless \
                mariadb-plugin-connect \
                mariadb-test-data \
                libmariadb-java -y \
                wget vim && \
    rm -rf /var/lib/apt/lists/*

RUN wget https://download.oracle.com/otn-pub/otn_software/jdbc/232-DeveloperRel/ojdbc11.jar

RUN cp ojdbc11.jar /usr/share/java/