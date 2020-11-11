#!/bin/bash

cd /code
[ -d PyMySQL ] || git clone https://github.com/PyMySQL/PyMySQL.git
cd PyMySQL
git clean -dfx
git pull

curl https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot.mariadb.org/dockerfiles/eco-files/installdb.sh | bash -s

mysql -u root <<EOF

/*M!100301 INSTALL SONAME "auth_ed25519" */;
/*M!100301 CREATE FUNCTION ed25519_password RETURNS STRING SONAME "auth_ed25519.so" */;
/* we need to pass the hashed password manually until 10.4, so hide it here */
/*M!100301 EXECUTE IMMEDIATE CONCAT('CREATE USER nopass_ed25519 IDENTIFIED VIA ed25519 USING "', ed25519_password(""),'"') */;
/*M!100301 EXECUTE IMMEDIATE CONCAT('CREATE USER user_ed25519 IDENTIFIED VIA ed25519 USING "', ed25519_password("pass_ed25519"),'"') */;

create database IF NOT EXISTS test1 DEFAULT CHARACTER SET utf8mb4;
create database IF NOT EXISTS test2 DEFAULT CHARACTER SET utf8mb4;
create user IF NOT EXISTS test2           identified by 'some password'; grant all on test2.* to test2;
create user IF NOT EXISTS test2@localhost identified by 'some password'; grant all on test2.* to test2@localhost;
EOF

cat > pymysql/tests/databases.json <<EOF
[
    {"host": "localhost", "unix_socket": "/tmp/mysql.sock", "user": "root", "passwd": "", "db": "test1",  "use_unicode": true, "local_infile": true},
    {"host": "127.0.0.1", "port": 3306, "user": "test2", "password": "some password", "db": "test2" }
]
EOF

pytest -v pymysql

$(mysql -u root  --skip-column-names  -Be "SELECT IF(LEFT(VERSION(),4)!='10.2', 'pytest -v tests/test_mariadb_auth.py','')")
