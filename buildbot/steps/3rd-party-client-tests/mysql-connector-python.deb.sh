#!/bin/bash -x

# python3-setuptools python-setuptools
sudo apt-get install -y python3 dh-python
cd mysql-connector-python-*/

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

grep '^\(FAIL\|ERROR\):' build.log | tee /tmp/test.out
