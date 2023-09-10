
execfile("/etc/buildbot/builders/server-installation.py");
execfile("/etc/buildbot/builders/cc-installation.py");

def step0_checkout(reponame, withSubmodule=True):
    result= """
set -ex
if [ -e ~/libssl-dev*.deb ] ; then sudo dpkg -i ~/libssl-dev*.deb ; fi
git --version
rm -Rf build
rm -Rf src
rm -Rf install_test
time git clone -b %(branch)s \"""" + reponame +"""" src
cd src
! [ -z "%(revision)s" ] && git reset --hard %(revision)s
"""
    if withSubmodule:
        result=result + """
git submodule init
git submodule update
cd libmariadb
git fetch --all --tags --prune
git log | head -n5
cd .."""
    return result + """
cd ..
mkdir build
cd build

"""

step0_set_test_env= """
# At least uid has to be exported before cmake run
export TEST_UID=root
export TEST_PASSWORD=
export TEST_PORT=3306
export TEST_SERVER=localhost
export TEST_SCHEMA=test
export TEST_VERBOSE=true

"""
step1_build= """
cmake --build . --config RelWithDebInfo --target package
ls -l mariadb-connector-* || ls -l mariadb*deb || ls -l mariadb*rpm
ls
"""
step4_testsrun= """
cd ./build/test
ls
ctest --output-on-failure
"""

