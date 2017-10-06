
################################# bld_linux_connector_oddbc ################################
def bld_linux_connector_odbc(name, port, kvm_image, cflags, yum, conc_branch, cmake_params):
    args= ["--port="+port, "--user=buildbot", "--smp=4", "--cpu=qemu64"]
    linux_connector_odbc= factory.BuildFactory()
    linux_connector_odbc.addStep(ShellCommand(
        description=["cleaning", "build", "dir"],
        descriptionDone=["clean", "build", "dir"],
        command=["sh", "-c", "rm -Rf ../build/*"]))
    linux_connector_odbc.addStep(ShellCommand(
        description=["rsyncing", "VMs"],
        descriptionDone=["rsync", "VMs"],
        doStepIf=(lambda(step): step.getProperty("slavename") != "bb01"),
        haltOnFailure=True,
        command=["rsync", "-a", "-v", "-L",
                 "bb01.mariadb.net::kvm/vms/"+kvm_image+"-build.qcow2",
                 "/kvm/vms/"]))
    linux_connector_odbc.addStep(Compile(
        description=["building", "linux-connctor_odbc"],
        descriptionDone=["build", "linux-connector_odbc"],
        timeout=3600,
        env={"TERM": "vt102"},
        command=["runvm", "--base-image=/kvm/vms/"+kvm_image+"-build.qcow2"] + args +["vm-tmp-"+port+".qcow2",
        "rm -Rf buildbot && mkdir buildbot",
        WithProperties("""
set -ex
rm -Rf build
mkdir connector_c
""" + ("""sudo yum --disablerepo=epel -y install git
sudo yum --disablerepo=epel -y install unixODBC
sudo yum -y install unixODBC-devel
""" if yum else """sudo apt-get update
sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get install --allow-unauthenticated -y git"
sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get install --allow-unauthenticated -y --force-yes -m unixodbc-dev"
""") + """time git clone -b """ + conc_branch + """ --depth 1 "https://github.com/MariaDB/mariadb-connector-c.git" build
cd build
export CFLAGS="${CFLAGS}"""+ cflags + """"
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo""" + cmake_params + """-DCMAKE_INSTALL_PREFIX= ../connector_c .
make
sudo make install
cd ..
rm build -rf
time git clone --depth 1 -b %(branch)s "https://github.com/MariaDB/mariadb-connector-odbc.git" build
cd build
rm -rf ./test
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo""" + cmake_params + """-DMARIADB_DIR=../connector_c .
cmake --build . --config RelWithDebInfo --target package
"""),
        "= scp -r -P "+port+" "+kvm_scpopt+" buildbot@localhost:/home/buildbot/build/mariadb*tar.gz .",
        ]))
    linux_connector_odbc.addStep(SetPropertyFromCommand(
        property="bindistname",
        command=["sh", "-c", WithProperties("basename `ls mariadb*odbc*tar.gz`")],
        ))
    addPackageUploadStep(linux_connector_odbc, '"%(bindistname)s"')
    return {'name': name, 'builddir': name,
            'factory': linux_connector_odbc,
            "slavenames": connector_slaves,
            "category": "connectors"}
######################## bld_linux_connector_oddbc - END #####################

######################## Current GA/stable version builders ######################
bld_linux_x64_connector_odbc= bld_linux_connector_odbc("linux_x64-connector-odbc", "2250", "vm-centos6-amd64", "", True, "connector_c_2.3", " -DWITH_OPENSSL=OFF -DSYSTEM_NAME=rhel6 ");
bld_linux_x86_connector_odbc= bld_linux_connector_odbc("linux_x86-connector-odbc", "2250", "vm-centos6-i386", "", True, "connector_c_2.3", " -DWITH_OPENSSL=OFF -DSYSTEM_NAME=rhel6 ");
bld_centos7_x64_connector_odbc= bld_linux_connector_odbc("centos7_x64-connector-odbc", "2250", "vm-centos7-amd64", "", True, "connector_c_2.3", " -DWITH_OPENSSL=OFF -DSYSTEM_NAME=rhel7 ");

bld_jessie_x86_connector_odbc= bld_linux_connector_odbc("jessie_x86-connector-odbc", "2250", "vm-jessie-i386", "", False, "connector_c_2.3", " -DWITH_OPENSSL=OFF  -DSYSTEM_NAME=debian ");
bld_jessie_x64_connector_odbc= bld_linux_connector_odbc("jessie_x64-connector-odbc", "2250", "vm-jessie-amd64", "", False, "connector_c_2.3", " -DWITH_OPENSSL=OFF -DSYSTEM_NAME=debian ");

bld_generic_x86_connector_odbc= bld_linux_connector_odbc("generic_x86-connector-odbc", "2250", "vm-centos5-i386", " -D_GNU_SOURCE", True, "connector_c_2.3", " -DWITH_OPENSSL=OFF ");
bld_generic_x64_connector_odbc= bld_linux_connector_odbc("generic_x64-connector-odbc", "2250", "vm-centos5-amd64", " -D_GNU_SOURCE", True, "connector_c_2.3", " -DWITH_OPENSSL=OFF ");
#################$### Current GA/stable version builders - END ###################

######################## New (unstable) version builders ######################
bld_linux_x64_connector_odbc_new= bld_linux_connector_odbc("linux_x64-connector-odbc-new", "2250", "vm-centos6-amd64", "", True, "master", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=rhel6 ");
bld_linux_x86_connector_odbc_new= bld_linux_connector_odbc("linux_x86-connector-odbc-new", "2250", "vm-centos6-i386", "", True, "master", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=rhel6 ");
bld_centos7_x64_connector_odbc_new= bld_linux_connector_odbc("centos7_x64-connector-odbc-new", "2250", "vm-centos7-amd64", "", True, "master", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=rhel7 ");

bld_jessie_x86_connector_odbc_new= bld_linux_connector_odbc("jessie_x86-connector-odbc-new", "2250", "vm-jessie-i386", "", False, "master", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=debian ");
bld_jessie_x64_connector_odbc_new= bld_linux_connector_odbc("jessie_x64-connector-odbc-new", "2250", "vm-jessie-amd64", "", False, "master", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=debian ");

bld_generic_x86_connector_odbc_new= bld_linux_connector_odbc("generic_x86-connector-odbc-new", "2250", "vm-centos5-i386", " -D_GNU_SOURCE", True, "master", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON ");
bld_generic_x64_connector_odbc_new= bld_linux_connector_odbc("generic_x64-connector-odbc-new", "2250", "vm-centos5-amd64", " -D_GNU_SOURCE", True, "master", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON ");
##################### New (unstable) version builders - END ###################


def bld_xcomp_linux_connector_odbc(name, port, kvm_image, conc_branch, cmake_params):
    args= ["--port="+port, "--user=buildbot", "--smp=4", "--cpu=qemu64"]
    linux_connector_odbc= factory.BuildFactory()
    linux_connector_odbc.addStep(ShellCommand(
        description=["cleaning", "build", "dir"],
        descriptionDone=["clean", "build", "dir"],
        command=["sh", "-c", "rm -Rf ../build/*"]))
    linux_connector_odbc.addStep(ShellCommand(
        description=["rsyncing", "VMs"],
        descriptionDone=["rsync", "VMs"],
        doStepIf=(lambda(step): step.getProperty("slavename") != "bb01"),
        haltOnFailure=True,
        command=["rsync", "-a", "-v", "-L",
                 "bb01.mariadb.net::kvm/vms/"+kvm_image+"-build.qcow2",
                 "/kvm/vms/"]))
    linux_connector_odbc.addStep(Compile(
        description=["building", "centos7-connctor_odbc"],
        descriptionDone=["build", "centos7-connector_odbc"],
        timeout=3600,
        env={"TERM": "vt102"},
        command=["runvm", "--base-image=/kvm/vms/"+kvm_image+"-build.qcow2"] + args +["vm-tmp-"+port+".qcow2",
        "rm -Rf buildbot && mkdir buildbot",
        WithProperties("""
set -ex
rm -Rf build
mkdir connector_c_32
#sudo yum -y install git
sudo yum --disablerepo=epel -y install git
sudo yum -y install unixODBC.x86_64
sudo yum -y install unixODBC.i686
sudo yum -y install unixODBC-devel.x86_64
sudo yum -y install unixODBC-devel.i686
sudo yum -y install zlib.x86_64
sudo yum -y install glibc-devel.i686 libstdc++-devel.i686 zlib.i686
sudo yum -y install openssl-devel.i686
time git clone -b """ + conc_branch + """ --depth 1 "https://github.com/MariaDB/mariadb-connector-c.git" build
cd build
setarch i386 cmake -DGSSAPI_FOUND=0 -DCMAKE_TOOLCHAIN_FILE=cmake/linux_x86_toolchain.cmake -DCMAKE_BUILD_TYPE=Debug""" + cmake_params + """-DCMAKE_INSTALL_PREFIX= ../connector_c_32 .
setarch i386 make
setarch i386 sudo make install
rm CMakeCache.txt CMakeFiles -rf
cd ..
rm build -rf
time git clone --depth 1 -b %(branch)s "https://github.com/MariaDB/mariadb-connector-odbc.git" build
cd build
rm -rf ./test
setarch i386 cmake -DCMAKE_BUILD_TYPE=Debug """ + cmake_params + """ -DCMAKE_TOOLCHAIN_FILE=cmake/linux_x86_toolchain.cmake -DMARIADB_DIR=../connector_c_32 .
setarch i386 cmake --build . --config Debug --target package
setarch i386 make package

#### Another way to go. For some reasons we used to go both
#make clean
#rm CMakeCache.txt CMakeFiles -rf
#export CFLAGS=-m32
#cmake . -DCMAKE_BUILD_TYPE=RelWithDebInfo -DMARIADB_DIR=../connector_c_32
#cmake --build . --config RelWithDebInfo --target package
#make package

"""),
###
#RelWithDebInfo
#setarch i386 cmake -DGSSAPI_FOUND=0 -DCMAKE_TOOLCHAIN_FILE=cmake/linux_x86_toolchain.cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo""" + cmake_params + """-DCMAKE_INSTALL_PREFIX= ../connector_c_32 .
#setarch i386 cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo """ + cmake_params + """ -DCMAKE_TOOLCHAIN_FILE=cmake/linux_x86_toolchain.cmake -DMARIADB_DIR=../connector_c_32 .
#setarch i386 cmake --build . --config RelWithDebInfo --target package
        "= scp -r -P "+port+" "+kvm_scpopt+" buildbot@localhost:/home/buildbot/build/mariadb*tar.gz .",
        ]))
    linux_connector_odbc.addStep(SetPropertyFromCommand(
        property="bindistname",
        command=["sh", "-c", WithProperties("basename `ls mariadb*odbc*tar.gz`")],
        ))
    addPackageUploadStep(linux_connector_odbc, '"%(bindistname)s"')
    return {'name': name, 'builddir': name,
            'factory': linux_connector_odbc,
            "slavenames": connector_slaves,
            "category": "connectors"}

bld_centos7_x86_connector_odbc= bld_xcomp_linux_connector_odbc("centos7_x86-connector-odbc", "2250", "vm-centos7-amd64", "connector_c_2.3", " -DWITH_OPENSSL=OFF -DSYSTEM_NAME=rhel7 ");
bld_centos7_x86_connector_odbc_new= bld_xcomp_linux_connector_odbc("centos7_x86-connector-odbc-new", "2250", "vm-centos7-amd64", "master", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=rhel7 ");

