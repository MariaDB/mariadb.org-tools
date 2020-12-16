#!/bin/bash -x

### Tests seen sporadically fail in MySQL:
# ERROR: bugs.BugOra21947091.test_ssl_disabled_pure
# FAIL: connection.MySQLConnectionTests.test_shutdown
# ERROR: bugs.Bug551533and586003.test_select (using MySQLConnection)
# ERROR: bugs.Bug865859.test_reassign_connection (using MySQLConnection)

### Tests seen sporadically fail in MariaDB:
# FAIL: bugs.BugOra18415927.test_auth_response
# ERROR: connection.MySQLConnectionTests.test_cmd_stmt_execute
# ERROR: tests.issues.test_bug21449207.Bug21449207.test_16M_compressed (using MySQLConnection)
# FAIL: cursor.MySQLCursorPreparedTests.test_execute

cd mysql-connector-python-*/

sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get install -y python3 dh-python debhelper dpkg-dev"
sed -ie "s/override_dh_auto_test/override_dh_auto_test_orig/g" debian/rules

cat >> debian/rules << EOF

override_dh_auto_test:
ifeq (,\$(findstring nocheck,\$(DEB_BUILD_OPTIONS)))
	-for python in \$(PYTHON2) \$(PYTHON3); do \\
               LIB=\$\$(\$\$python -c "from distutils.command.build import build ; from distutils.core import Distribution ; b = build(Distribution()) ; b.finalize_options() ; print (b.build_purelib)") ;\\
               mkdir -p /tmp/con-python/ ; \\
               PYTHONPATH=\$(CURDIR)/\$\$LIB \$\$python unittests.py --with-mysql=/usr/ --mysql-topdir=/tmp/con-python/ --verbosity=2 --bind-address=:: --host=::1 --stats ; \\
               rm -rf /tmp/con-python/ ; \\
       done
endif
EOF

sed -ie 's/^\(\s*\)def _get_version(self):.*$/\1def _get_version(self):\n\1\1return (5,6,99)/' tests/mysqld.py
sed -ie "s/'--is-wheel'//" tests/__init__.py

make -f debian/rules build 2>&1 | tee build.log

grep '^\(FAIL\|ERROR\):' build.log | grep -vE "bugs.BugOra21947091.test_ssl_disabled_pure|connection.MySQLConnectionTests.test_shutdown|bugs.Bug551533and586003.test_select|bugs.Bug865859.test_reassign_connection|bugs.BugOra18415927.test_auth_response|connection.MySQLConnectionTests.test_cmd_stmt_execute|tests.issues.test_bug21449207.Bug21449207.test_16M_compressed|cursor.MySQLCursorPreparedTests.test_execute" | tee /tmp/test.out
