#!/bin/bash

cd /code
[ -d PyMySQL ] || git clone https://github.com/PyMySQL/PyMySQL.git
cd PyMySQL
git clean -dfx
git pull --tags
if [ -n "$1" ]
then
  if [ ! -d ../"$1" ]
  then
    git worktree add ../"$1" "$1"
  fi
  cd ../"$1"
  git checkout origin/$1
fi

/usr/local/mariadb/bin/mysql -u root <<EOF

/*M!100301 INSTALL SONAME "auth_ed25519" */;
/*M!100301 CREATE FUNCTION ed25519_password RETURNS STRING SONAME "auth_ed25519.so" */;
/* we need to pass the hashed password manually until 10.4, so hide it here */
/*M!100301 EXECUTE IMMEDIATE CONCAT('CREATE USER nopass_ed25519 IDENTIFIED VIA ed25519 USING "', ed25519_password(""),'"') */;
/*M!100301 EXECUTE IMMEDIATE CONCAT('CREATE USER user_ed25519 IDENTIFIED VIA ed25519 USING "', ed25519_password("pass_ed25519"),'"') */;

create database test1 DEFAULT CHARACTER SET utf8mb4;
create database test2 DEFAULT CHARACTER SET utf8mb4;
create user test2           identified by 'some password';
grant all on test2.* to test2;
create user test2@localhost identified by 'some password';
grant all on test2.* to test2@localhost;
EOF

# Both passwd and password are aliased to the same, so this isn't an error in the below configuration.
cat > pymysql/tests/databases.json <<EOF
[
    {"host": "localhost", "unix_socket": "/tmp/mysql.sock", "user": "root", "passwd": "", "db": "test1",  "use_unicode": true, "local_infile": true},
    {"host": "127.0.0.1", "port": 3306, "user": "test2", "password": "some password", "db": "test2" }
]
EOF

pytest -v pymysql

if [ -f tests/test_mariadb_auth.py ]
then
  $(mysql -u root  --skip-column-names  -Be "SELECT IF(LEFT(VERSION(),4)!='10.2', 'pytest -v tests/test_mariadb_auth.py',';')")
fi
