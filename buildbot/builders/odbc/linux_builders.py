
################################# bld_linux_connector_oddbc ################################
def bld_linux_connector_odbc(name, kvm_image, cflags, yum, conc_branch, cmake_params, tag):
    linux_connector_odbc= BuildFactory()
    args= ["--port="+getport(), "--user=buildbot", "--smp=4", "--cpu=qemu64"]
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
        command=["runvm", "--base-image=/kvm/vms/"+kvm_image+"-build.qcow2"] + args +["vm-tmp-"+getport()+".qcow2",
        "rm -Rf buildbot && mkdir buildbot",
        WithProperties("""
set -ex
git --version
rm -Rf build
mkdir connector_c
""" + (""" sudo yum --disablerepo=epel -y install unixODBC
sudo yum -y install unixODBC-devel
""" if yum else """sudo apt-get update
sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get install --allow-unauthenticated -y --force-yes -m unixodbc-dev"
""") + """export CFLAGS="${CFLAGS}"""+ cflags + """"
time git clone --depth 1 -b %(branch)s "https://github.com/MariaDB/mariadb-connector-odbc.git" build
cd build
rm -rf ./test
git submodule init
git submodule update
cd libmariadb
git fetch --all --tags --prune
git checkout """+ tag + """
git log | head -n5
cd ..
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCONC_WITH_UNIT_TESTS=Off""" + cmake_params + """ .
cmake --build . --config RelWithDebInfo --target package
"""),
        "= scp -r -P "+getport()+" "+kvm_scpopt+" buildbot@localhost:/home/buildbot/build/mariadb*tar.gz .",
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
#sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get install --allow-unauthenticated -y git"
#sudo yum --disablerepo=epel -y install git

######################## Current GA/stable version builders ######################
bld_linux_x64_connector_odbc= bld_linux_connector_odbc("linux_x64-connector-odbc", "vm-centos6-amd64", "", True, "connector_c_2.3", " -DWITH_OPENSSL=OFF -DSYSTEM_NAME=rhel6 ", "v_2.3.6");
bld_linux_x86_connector_odbc= bld_linux_connector_odbc("linux_x86-connector-odbc", "vm-centos6-i386", "", True, "connector_c_2.3", " -DWITH_OPENSSL=OFF -DSYSTEM_NAME=rhel6 ", "v_2.3.6");
bld_centos7_x64_connector_odbc= bld_linux_connector_odbc("centos7_x64-connector-odbc", "vm-centos7-amd64", "", True, "connector_c_2.3", " -DWITH_OPENSSL=OFF -DSYSTEM_NAME=rhel7 ", "v_2.3.6");

bld_jessie_x86_connector_odbc= bld_linux_connector_odbc("jessie_x86-connector-odbc", "vm-jessie-i386", "", False, "connector_c_2.3", " -DWITH_OPENSSL=OFF  -DSYSTEM_NAME=debian ", "v_2.3.6");
bld_jessie_x64_connector_odbc= bld_linux_connector_odbc("jessie_x64-connector-odbc", "vm-jessie-amd64", "", False, "connector_c_2.3", " -DWITH_OPENSSL=OFF -DSYSTEM_NAME=debian ", "v_2.3.6");

bld_generic_x86_connector_odbc= bld_linux_connector_odbc("generic_x86-connector-odbc", "vm-centos5-i386", " -D_GNU_SOURCE", True, "connector_c_2.3", " -DWITH_OPENSSL=OFF ", "v_2.3.6");
bld_generic_x64_connector_odbc= bld_linux_connector_odbc("generic_x64-connector-odbc", "vm-centos5-amd64", " -D_GNU_SOURCE", True, "connector_c_2.3", " -DWITH_OPENSSL=OFF ", "v_2.3.6");
#################$### Current GA/stable version builders - END ###################

######################## New (unstable) version builders ######################
bld_linux_x64_connector_odbc_new= bld_linux_connector_odbc("linux_x64-connector-odbc-new", "vm-centos6-amd64", "", True, "3.0", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=rhel6 ", "v3.0.8-release");
bld_linux_x86_connector_odbc_new= bld_linux_connector_odbc("linux_x86-connector-odbc-new", "vm-centos6-i386", "", True, "3.0", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=rhel6 ", "v3.0.8-release");
bld_centos7_x64_connector_odbc_new= bld_linux_connector_odbc("centos7_x64-connector-odbc-new", "vm-centos7-amd64", "", True, "3.0", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=rhel7 ", "v3.0.8-release");
bld_opensuse42_x64_connector_odbc_new= bld_linux_connector_odbc("opensuse42_x64-connector-odbc-new", "vm-opensuse42-amd64", "", True, "3.0", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=suse", "v3.0.8-release");

bld_jessie_x86_connector_odbc_new= bld_linux_connector_odbc("jessie_x86-connector-odbc-new", "vm-jessie-i386", "", False, "3.0", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=debian ", "v3.0.8-release");
bld_jessie_x64_connector_odbc_new= bld_linux_connector_odbc("jessie_x64-connector-odbc-new", "vm-jessie-amd64", "", False, "3.0", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=debian ", "v3.0.8-release");

bld_generic_x86_connector_odbc_new= bld_linux_connector_odbc("generic_x86-connector-odbc-new", "vm-centos5-i386", " -D_GNU_SOURCE", True, "3.0", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON ", "v3.0.8-release");
bld_generic_x64_connector_odbc_new= bld_linux_connector_odbc("generic_x64-connector-odbc-new", "vm-centos5-amd64", " -D_GNU_SOURCE", True, "3.0", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON ", "v3.0.8-release");
##################### New (unstable) version builders - END ###################


def bld_xcomp_linux_connector_odbc(name, kvm_image, conc_branch, cmake_params, tag):
    linux_connector_odbc= BuildFactory()
    args= ["--port="+getport(), "--user=buildbot", "--smp=4", "--cpu=qemu64"]
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
        command=["runvm", "--base-image=/kvm/vms/"+kvm_image+"-build.qcow2"] + args +["vm-tmp-"+getport()+".qcow2",
        "rm -Rf buildbot && mkdir buildbot",
        WithProperties("""
set -ex
rm -Rf build
#sudo yum -y install git
sudo yum --disablerepo=epel -y install git
sudo yum -y install unixODBC.x86_64
sudo yum -y install unixODBC.i686
sudo yum -y install unixODBC-devel.x86_64
sudo yum -y install unixODBC-devel.i686
sudo yum -y install zlib.x86_64
sudo yum -y install glibc-devel.i686 libstdc++-devel.i686 zlib.i686
sudo yum -y install openssl-devel.i686
sudo yum -y install libcom_err.i686
sudo ldconfig
time git clone --depth 1 -b %(branch)s "https://github.com/MariaDB/mariadb-connector-odbc.git" build
cd build
rm -rf ./test
git submodule init
git submodule update
cd libmariadb
git fetch --all --tags --prune
git checkout """+ tag + """
git log | head -n5
cd ..
setarch i386 cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo """ + cmake_params + """ -DCMAKE_TOOLCHAIN_FILE=cmake/linux_x86_toolchain.cmake .
setarch i386 cmake --build . --config RelWithDebInfo --target package
setarch i386 make package
"""),
        "= scp -r -P "+getport()+" "+kvm_scpopt+" buildbot@localhost:/home/buildbot/build/mariadb*tar.gz .",
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

bld_centos7_x86_connector_odbc= bld_xcomp_linux_connector_odbc("centos7_x86-connector-odbc", "vm-centos7-amd64", "connector_c_2.3", " -DWITH_OPENSSL=OFF -DSYSTEM_NAME=rhel7 ", "v_2.3.6");
bld_centos7_x86_connector_odbc_new= bld_xcomp_linux_connector_odbc("centos7_x86-connector-odbc-new", "vm-centos7-amd64", "3.0", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=rhel7 ", "v3.0.8-release");

