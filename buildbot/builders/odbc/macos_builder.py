def build_macos_connector_odbc(name, cmake_params):

  f_macos_connector_odbc = BuildFactory()

  f_macos_connector_odbc.addStep(ShellCommand(
        name = "remove_old_build",
        command=["sh", "-c", "pwd && /bin/rm -rf " , 
        WithProperties("~/conn-slave/%(buildername)s/build")],
        timeout = 4*3600,
        haltOnFailure = True
  ));

  f_macos_connector_odbc.addStep(SetPropertyFromCommand(
        property="buildrootdir",
        command=["pwd"]
  ))
# f_macos_connector_odbc.addStep(maybe_git_checkout)
  f_macos_connector_odbc.addStep(ShellCommand(
        name= "git_checkout",
        command=["sh", "-c", WithProperties("rm -rf src && git clone -b %(branch)s %(repository)s src && cd src && git reset --hard %(revision)s && ls")],
        timeout=7200
  ));

  f_macos_connector_odbc.addStep(ShellCommand(
        name= "git_conc_checkout",
        command=["sh", "-c", WithProperties("cd src && git submodule init && git submodule update && cd libmariadb && git fetch --all --tags --prune")],
        timeout=7200
  ));

  f_macos_connector_odbc.addStep(ShellCommand(
        name= "build_package",
        command=["sh", "-c",
#        WithProperties("rm -rf build && mkdir build && cd build && cmake ../src -G Xcode -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_SSL=OPENSSL -DOPENSSL_ROOT_DIR=/usr/local/opt/openssl/\\@1.1 -DOPENSSL_SSL_LIBRARY=/usr/local/opt/openssl/\\@1.1/lib/libssl.dylib -DOPENSSL_INCLUDE_DIR=/usr/local/opt/openssl/\\@1.1/include -DOPENSSL_CRYPTO_LIBRARY=/usr/local/opt/openssl/\\@1.1/lib/libcrypto.dylib -DWITH_SIGNCODE=OFF -DCONC_WITH_UNIT_TESTS=OFF -DODBC_INCLUDE_DIR=/usr/local/iODBC/include -DODBC_LIB_DIR=/usr/local/iODBC/lib -DWITH_EXTERNAL_ZLIB=On" + cmake_params + " && cmake --build . --config RelWithDebInfo || cmake --build . --config RelWithDebInfo")
        WithProperties("""
export TEST_DSN=maodbc_test
export TEST_SERVER=localhost
export TEST_SOCKET=
export TEST_SCHEMA=%(buildername)s%(revision)s
export TEST_UID=root
export TEST_PASSWORD=root
TEST_SCHEMA=`echo ${TEST_SCHEMA:0:31} | tr '-' '_'`

rm -rf build && mkdir build && cd build && cmake ../src -G Xcode -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_SSL=OPENSSL -DOPENSSL_ROOT_DIR=/usr/local/opt/openssl@1.1 -DWITH_SIGNCODE=OFF -DCONC_WITH_UNIT_TESTS=OFF -DODBC_INCLUDE_DIR=/usr/local/iODBC/include -DODBC_LIB_DIR=/usr/local/iODBC/lib -DWITH_EXTERNAL_ZLIB=On" + cmake_params + " && cmake --build . --config RelWithDebInfo || cmake --build . --config RelWithDebInfo""")
          ],
        haltOnFailure = True
	));

  f_macos_connector_odbc.addStep(ShellCommand(
        name= "tests_run",
        command=["sh", "-c", WithProperties("""
cd build
export TEST_DRIVER="$PWD/RelWithDebInfo/libmaodbc.dylib"
export TEST_DSN=maodbc_test
export TEST_SERVER=localhost
export TEST_SOCKET=
export TEST_SCHEMA=%(buildername)s%(revision)s
export TEST_UID=root
export TEST_PASSWORD=root
TEST_SCHEMA=`echo ${TEST_SCHEMA:0:31} | tr '-' '_'`

export ODBCINI="$PWD/test/odbc.ini"
cat ${ODBCINI}
export ODBCINSTINI="$PWD/test/odbcinst.ini"
cat ${ODBCINSTINI}

# check users of MariaDB and create test database
set +e
cd test
mariadb -u $TEST_UID -p$TEST_PASSWORD -e "DROP DATABASE IF EXISTS $TEST_SCHEMA"
mariadb -u $TEST_UID -p$TEST_PASSWORD -e "CREATE DATABASE $TEST_SCHEMA"

ctest --output-on-failure
""")],
        timeout=7200,
        haltOnFailure = True
  ));

  f_macos_connector_odbc.addStep(ShellCommand(
        name= "try_install_package",
        command=["sh", "-c",
        WithProperties("""
if installer -pkg ./build/osxinstall/mariadb-connector-odbc-*-osx-x86_64.pkg -target CurrentUserHomeDirectory ; then
  echo "Packege was successfully installed!";
else
  echo "There is still a problem installing with bb user";
fi
 """)]
        ))

  f_macos_connector_odbc.addStep(ShellCommand(
        name= "uninstall_package",
        command=["sh", "-c",
        WithProperties("""
 if pkgutil --pkgs --volume ~| grep com.mariadb.connector.odbc ; then
   cd ~
   pkgutil --only-dirs --files com.mariadb.connector.odbc --volume ~ | grep MariaDB-Connector-ODBC | grep -v "MariaDB-Connector-ODBC/" | tr '\n' ' ' | xargs -n 1 -0 sudo rm -rf
   [ -d Library/ODBC ] && rm -rf Library/ODBC
   pkgutil --forget com.mariadb.connector.odbc --volume ~;
 fi
 """)]
        ))

  f_macos_connector_odbc.addStep(ShellCommand(
        name= "create_publish_dir",
        command=["sh", "-c",
        WithProperties("mkdir -p ~/build_archive/%(buildername)s/%(branch)s/%(revision)s || exit 0")]
        ))

  f_macos_connector_odbc.addStep(ShellCommand(
        name= "publish",
        command=["sh", "-c",
        WithProperties("cd build && cp osxinstall/*.pkg ~/build_archive/%(buildername)s/%(branch)s/%(revision)s && md5 ~/build_archive/%(buildername)s/%(branch)s/%(revision)s/mariadb-connector-*pkg > ~/build_archive/%(buildername)s/%(branch)s/%(revision)s/md5.txt")]
  ))

  f_macos_connector_odbc.addStep(ShellCommand(
        name= "create_upload_dir",
        command=["sh", "-c",
        WithProperties("[ ! -d \"~/upload/%(buildername)s/%(revision)s\" ] && ! mkdir -p ~/upload/%(buildername)s/%(revision)s || cp ~/build_archive/%(buildername)s/%(branch)s/%(revision)s/mariadb-connector-*pkg ~/build_archive/%(buildername)s/%(branch)s/%(revision)s/*txt ~/upload/%(buildername)s/%(revision)s")]
  ))

  addPackageUploadStep(f_macos_connector_odbc, "~/upload/%(buildername)s/%(revision)s/*")

  f_macos_connector_odbc.addStep(ShellCommand(
        name= "rm_upload_dir",
        command=["sh", "-c",
        WithProperties("rm -rf \"~/upload/%(buildername)s/%(revision)s\"")]
  ))

  return { 'name': name,
#        'slavename': "bb-win32",
        'slavename': "conn-macincloud",
        'builddir': name,
        'factory': f_macos_connector_odbc,
        'category': "connectors" }

bld_macos_connector_odbc = build_macos_connector_odbc("codbc-macos", " -DINSTALL_PLUGINDIR=plugin")

