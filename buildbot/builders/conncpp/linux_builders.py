
################################# bld_linux_connector_oddbc ################################

conncpp_linux_step0_checkout= """
set -ex
if [ -e ~/libssl-dev*.deb ] ; then sudo dpkg -i ~/libssl-dev*.deb ; fi
git --version
rm -Rf build
rm -Rf src
rm -Rf install_test
time git clone --depth 1 -b %(branch)s "https://github.com/MariaDB-Corporation/mariadb-connector-cpp.git" src
cd src
[-z "%(revision)s"] && git checkout %(revision)s

git submodule init
git submodule update
cd libmariadb
git fetch --all --tags --prune
git log | head -n5
cd ../..
mkdir build
cd build

# At least uid has to be exported before cmake run
export TEST_UID=root
export TEST_PASSWORD=
export TEST_SERVER=localhost
export TEST_SCHEMA=test

"""
conncpp_linux_step1_build= """
cmake --build . --config RelWithDebInfo --target package
ls -l mariadb-connector-cpp*
ls
"""
conncpp_linux_step2_serverinstall= """
# Installing server to run tests
if [ -e /usr/bin/apt ] ; then
  sudo apt update
# This package is required to run following script
  sudo apt install -y apt-transport-https
  sudo apt install -y curl
fi

if ! curl -LsS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash ; then
  if [ -e /etc/fedora-release ]; then
    source /etc/os-release
    sudo sh -c "echo \\"#MariaDB.Org repo
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.5/$ID$VERSION_ID-amd64
gpgkey = https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck = 1\\" > /etc/yum.repos.d/mariadb.repo"
    sudo rpm --import https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
    sudo dnf remove -y mariadb-connector-c-config
  fi
  if grep -i xenial /etc/os-release ; then
    USEAPT=1
    sudo apt-get install -y software-properties-common gnupg-curl
    sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
    sudo add-apt-repository -y 'deb [arch=amd64,arm64,i386,ppc64el] https://mirrors.ukfast.co.uk/sites/mariadb/repo/10.5/ubuntu xenial main'
  fi
  if grep -i groovy /etc/os-release ; then
    USEAPT=1
    sudo apt-get install -y software-properties-common
    sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
    sudo add-apt-repository -y 'deb [arch=amd64,arm64,i386,ppc64el] https://mirrors.ukfast.co.uk/sites/mariadb/repo/10.5/ubuntu groovy main'
  fi
fi

if [ -e "/etc/yum.repos.d/mariadb.repo" ]; then
  if ! sudo dnf install -y MariaDB-server ; then
    sudo yum install -y MariaDB-server
  fi
  sudo systemctl start mariadb
fi

if [ ! -z "$USEAPT" ] || [ -e "/etc/apt/sources.list.d/mariadb.list" ]; then
#  export TEST_PASSWORD=rootpass
  sudo apt update
  sudo apt install -y apt-transport-https
  sudo apt install -y mariadb-server
fi

if [ -e "/etc/zypp/repos.d/mariadb.repo" ]; then
  sudo zypper install -y MariaDB-server
  sudo systemctl start mariadb
fi

sudo mariadb -u root -e "select version(),@@port, @@socket"
sudo mariadb -u root -e "set password=\\"\\""
sudo mariadb -u root -e "DROP DATABASE IF EXISTS test"
sudo mariadb -u root -e "CREATE DATABASE test"
sudo mariadb -u root -e "SELECT * FROM mysql.user"
SOCKETPATH=$(mariadb -u root test -N -B -e "select @@socket")
echo $SOCKETPATH

cd ..
"""
conncpp_linux_step3_packagetest= """
if [ -d "./src/install_test" ]; then
  cat ./src/install_test/CMakeLists.txt
  mkdir ./install_test
  cd install_test
  cmake ../src/install_test
  cmake --build . --config RelWithDebInfo
  cat ./CMakeFiles/example.dir/link.txt
  PACKLIBS=$(ls $PWD/mariadb-connector-cpp*/lib*/mariadb/libmariadb.*)
  PACKLIBS=$(dirname $PACKLIBS)
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$PACKLIBS
  ldd ./example
  readelf -d $PACKLIBS/libmariadbcpp.so*
  ./example "$TEST_UID" "$TEST_PASSWORD" "$SOCKETPATH"
fi
cd ..
"""
conncpp_linux_step4_testsrun= """
cd ./build/test
ls
ctest -VV
"""

def bld_linux_connector_cpp(name, kvm_image, cflags, cmake_params):
    linux_connector_cpp= BuildFactory()
    args= ["--port="+getport(), "--user=buildbot", "--smp=4", "--cpu=qemu64"]
    linux_connector_cpp.addStep(ShellCommand(
        description=["cleaning", "build", "dir"],
        descriptionDone=["clean", "build", "dir"],
        command=["sh", "-c", "rm -Rf ../build/*"]))
    linux_connector_cpp.addStep(ShellCommand(
        description=["rsyncing", "VMs"],
        descriptionDone=["rsync", "VMs"],
        doStepIf=(lambda(step): step.getProperty("slavename") != "bb01"),
        haltOnFailure=True,
        command=["rsync", "-a", "-v", "-L",
                 "bb01.mariadb.net::kvm/vms/"+kvm_image+"-build.qcow2",
                 "/kvm/vms/"]))
    linux_connector_cpp.addStep(Compile(
        description=["building", "linux-connctor_cpp"],
        descriptionDone=["build", "linux-connector_cpp"],
        timeout=3600,
        env={"TERM": "vt102"},
        command=["runvm", "--base-image=/kvm/vms/"+kvm_image+"-build.qcow2"] + args +["vm-tmp-"+getport()+".qcow2",
        "rm -Rf buildbot && mkdir buildbot",
        WithProperties("""
export CFLAGS="${CFLAGS}"""+ cflags + """" """ +
conncpp_linux_step0_checkout + """
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCONC_WITH_UNIT_TESTS=Off -DPACKAGE_PLATFORM_SUFFIX=$HOSTNAME""" + cmake_params + """ ../src""" +
conncpp_linux_step1_build +
conncpp_linux_step2_serverinstall +
conncpp_linux_step3_packagetest +
conncpp_linux_step4_testsrun
),
        "= scp -r -P "+getport()+" "+kvm_scpopt+" buildbot@localhost:/home/buildbot/build/mariadb*tar.gz .",
        ]))
    linux_connector_cpp.addStep(SetPropertyFromCommand(
        property="bindistname",
        command=["sh", "-c", WithProperties("basename `ls mariadb*tar.gz`")],
        ))
    addPackageUploadStep(linux_connector_cpp, '"%(bindistname)s"')
    return {'name': name, 'builddir': name,
            'factory': linux_connector_cpp,
            "slavenames": connector_slaves,
            "category": "connectors"}
######################## bld_linux_connector_oddbc - END #####################

######################## Current GA/stable version builders ######################
#################$### Current GA/stable version builders - END ###################

######################## New (unstable) version builders ######################
bld_centos8_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-centos8-amd64", "vm-centos8-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON ");
bld_stretch_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-stretch-amd64", "vm-stretch-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON ");

bld_sles15_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-sles15-amd64", "vm-sles150-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_xenial_x86_connector_cpp= bld_linux_connector_cpp("ccpp-xenial-x86", "vm-xenial-i386", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_xenial_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-xenial-amd64", "vm-xenial-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");

bld_bionic_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-bionic-amd64", "vm-bionic-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_focal_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-focal-amd64", "vm-focal-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_groovy_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-groovy-amd64", "vm-groovy-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_buster_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-buster-amd64", "vm-buster-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_fedora32_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-fedora32-amd64", "vm-fedora32-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_fedora33_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-fedora33-amd64", "vm-fedora33-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_sles12_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-sles12-amd64", "vm-sles123-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");

##################### Building with old gcc with the hack ###################

def bld_linux_connector_cpp_with_hack(name, kvm_image, cflags, cmake_params):
    linux_connector_cpp= BuildFactory()
    args= ["--port="+getport(), "--user=buildbot", "--smp=4", "--cpu=qemu64"]
    linux_connector_cpp.addStep(ShellCommand(
        description=["cleaning", "build", "dir"],
        descriptionDone=["clean", "build", "dir"],
        command=["sh", "-c", "rm -Rf ../build/*"]))
    linux_connector_cpp.addStep(ShellCommand(
        description=["rsyncing", "VMs"],
        descriptionDone=["rsync", "VMs"],
        doStepIf=(lambda(step): step.getProperty("slavename") != "bb01"),
        haltOnFailure=True,
        command=["rsync", "-a", "-v", "-L",
                 "bb01.mariadb.net::kvm/vms/"+kvm_image+"-connector.qcow2",
                 "/kvm/vms/"]))
    linux_connector_cpp.addStep(Compile(
        description=["building", "linux-connctor_cpp"],
        descriptionDone=["build", "linux-connector_cpp"],
        timeout=3600,
        env={"TERM": "vt102"},
        command=["runvm", "--base-image=/kvm/vms/"+kvm_image+"-connector.qcow2"] + args +["vm-tmp-"+getport()+".qcow2",
        "rm -Rf buildbot && mkdir buildbot",
        WithProperties("""
export CFLAGS="${CFLAGS}"""+ cflags + """" """ +
conncpp_linux_step0_checkout + """
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCONC_WITH_UNIT_TESTS=Off -DPACKAGE_PLATFORM_SUFFIX=$HOSTNAME""" + cmake_params + """ ../src""" +
conncpp_linux_step1_build +
conncpp_linux_step2_serverinstall +
conncpp_linux_step3_packagetest +
conncpp_linux_step4_testsrun
),
        "= scp -r -P "+getport()+" "+kvm_scpopt+" buildbot@localhost:/home/buildbot/build/mariadb*tar.gz .",
        ]))
    linux_connector_cpp.addStep(SetPropertyFromCommand(
        property="bindistname",
        command=["sh", "-c", WithProperties("basename `ls mariadb*tar.gz`")],
        ))
    addPackageUploadStep(linux_connector_cpp, '"%(bindistname)s"')
    return {'name': name, 'builddir': name,
            'factory': linux_connector_cpp,
            "slavenames": connector_slaves,
            "category": "connectors"}
bld_centos7_amd64_connector_cpp= bld_linux_connector_cpp_with_hack("ccpp-centos7-amd64", "vm-centos74-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON ");
