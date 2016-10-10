
################################# bld_linux_connector_oddbc ################################
def bld_linux_connector_odbc(name, port, kvm_image, cflags, yum):
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
""") + """time git clone -b connector_c_2.3 --depth 1 "https://github.com/MariaDB/mariadb-connector-c.git" build
cd build
cmake -DWITH_OPENSSL=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX= ../connector_c .
make
sudo make install
rm CMakeCache.txt CMakeFiles -rf
cmake . -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=../connector_c
make
sudo make install
cd ..
rm build -rf
time git clone --depth 1 -b odbc-2.0 "https://github.com/MariaDB/mariadb-connector-odbc.git" build
cd build
export CFLAGS="${CFLAGS}"""+ cflags + """"
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_OPENSSL=OFF -DMARIADB_DIR=../connector_c .
cmake --build . --config RelWithDebInfo --target package
make clean
rm CMakeCache.txt CMakeFiles -rf
cmake . -DCMAKE_BUILD_TYPE=RelWithDebInfo -DMARIADB_DIR=../connector_c
cmake --build . --config RelWithDebInfo --target package
make clean
rm CMakeCache.txt CMakeFiles -rf
cmake . -DCMAKE_BUILD_TYPE=RelWithDebInfo -DMARIADB_DIR=../connector_c
cmake --build . --config RelWithDebInfo --target package
make package

"""),
        "= scp -r -P "+port+" "+kvm_scpopt+" buildbot@localhost:/home/buildbot/build/mariadb*tar.gz .",
        ]))
    linux_connector_odbc.addStep(SetPropertyFromCommand(
        property="bindistname",
        command=["sh", "-c", WithProperties("basename `ls mariadb*linux*tar.gz`")],
        ))
    addPackageUploadStep(linux_connector_odbc, '"%(bindistname)s"')
    return {'name': name, 'builddir': name,
            'factory': linux_connector_odbc,
            "slavenames": connector_slaves,
            "category": "connectors"}
######################## bld_linux_connector_oddbc - END #####################

bld_linux_x64_connector_odbc= bld_linux_connector_odbc("linux_x64-connector-odbc", "2250", "vm-centos6-amd64", "", True);
bld_linux_x86_connector_odbc= bld_linux_connector_odbc("linux_x86-connector-odbc", "2250", "vm-centos6-i386", "", True);
bld_centos7_x64_connector_odbc= bld_linux_connector_odbc("centos7_x64-connector-odbc", "2250", "vm-centos7-amd64", "", True);
# These two are not usable atm
bld_jessie_x86_connector_odbc= bld_linux_connector_odbc("jessie_x86-connector-odbc", "2250", "vm-jessie-i386", "", False);
bld_jessie_x64_connector_odbc= bld_linux_connector_odbc("jessie_x64-connector-odbc", "2250", "vm-jessie-amd64", "", False);

bld_generic_x86_connector_odbc= bld_linux_connector_odbc("generic_x86-connector-odbc", "2250", "vm-centos5-i386", " -D_GNU_SOURCE", True);
bld_generic_x64_connector_odbc= bld_linux_connector_odbc("generic_x64-connector-odbc", "2250", "vm-centos5-amd64", " -D_GNU_SOURCE", True);

def bld_xcomp_linux_connector_odbc(name, port, kvm_image):
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
time git clone -b connector_c_2.3 --depth 1 "https://github.com/MariaDB/mariadb-connector-c.git" build
cd build
setarch i386 cmake -DWITH_OPENSSL=OFF -DCMAKE_TOOLCHAIN_FILE=cmake/linux_x86_toolchain.cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX= ../connector_c_32 .
setarch i386 make
setarch i386 sudo make install
rm CMakeCache.txt CMakeFiles -rf
cmake . -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=../connector_c_32
make
sudo make install
cd ..
rm build -rf
time git clone --depth 1 -b odbc-2.0 "https://github.com/MariaDB/mariadb-connector-odbc.git" build
cd build
setarch i386 cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_OPENSSL=OFF -DCMAKE_TOOLCHAIN_FILE=cmake/linux_x86_toolchain.cmake -DMARIADB_DIR=../connector_c_32 .
setarch i386 cmake --build . --config RelWithDebInfo --target package
setarch i386 make package
make clean
rm CMakeCache.txt CMakeFiles -rf

export CFLAGS=-m32

cmake . -DCMAKE_BUILD_TYPE=RelWithDebInfo -DMARIADB_DIR=../connector_c_32
cmake --build . --config RelWithDebInfo --target package
make package

"""),
        "= scp -r -P "+port+" "+kvm_scpopt+" buildbot@localhost:/home/buildbot/build/mariadb*tar.gz .",
        ]))
    linux_connector_odbc.addStep(SetPropertyFromCommand(
        property="bindistname",
        command=["sh", "-c", WithProperties("basename `ls mariadb*linux*tar.gz`")],
        ))
    addPackageUploadStep(linux_connector_odbc, '"%(bindistname)s"')
    return {'name': name, 'builddir': name,
            'factory': linux_connector_odbc,
            "slavenames": connector_slaves,
            "category": "connectors"}

bld_centos7_x86_connector_odbc= bld_xcomp_linux_connector_odbc("centos7_x86-connector-odbc", "2250", "vm-centos7-amd64");

