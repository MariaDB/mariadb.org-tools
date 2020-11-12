def build_linux_connector_odbc(name, kvm_image, cflags, cmake_params):
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
#sudo zypper install unixODBC-devel
#sudo zypper install libopenssl1_1
#sudo zypper install libopenssl-devel
#sudo yum --disablerepo=epel -y install unixODBC
#sudo yum -y install unixODBC-devel
#sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get install --allow-unauthenticated -y --force-yes -m unixodbc-dev"
#sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get install --allow-unauthenticated -y --force-yes -m openssl libssl-dev"
set -ex
if [ -e ~/libssl-dev*.deb ] ; then sudo dpkg -i ~/libssl-dev*.deb ; fi
git --version
rm -Rf build
export CFLAGS="${CFLAGS}"""+ cflags + """"
time git clone --depth 1 -b %(branch)s "https://github.com/MariaDB/mariadb-connector-odbc.git" build
[-z "%(revision)s"] && git checkout %(revision)s
cd build
rm -rf ./test
git submodule init
git submodule update
cd libmariadb
git fetch --all --tags --prune
git log | head -n5
cd ..
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCONC_WITH_UNIT_TESTS=Off -DPACKAGE_PLATFORM_SUFFIX=$HOSTNAME -DWITH_UNIT_TESTS=Off""" + cmake_params + """ .
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

bld_codbc_sles15_amd64= build_linux_connector_odbc("codbc-sles15-amd64", "vm-sles150-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_codbc_xenial_x86= build_linux_connector_odbc("codbc-xenial-x86", "vm-xenial-i386", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_codbc_xenial_amd64= build_linux_connector_odbc("codbc-xenial-amd64", "vm-xenial-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");

bld_codbc_bionic_amd64= build_linux_connector_odbc("codbc-bionic-amd64", "vm-bionic-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_codbc_focal_amd64= build_linux_connector_odbc("codbc-focal-amd64", "vm-focal-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_codbc_groovy_amd64= build_linux_connector_odbc("codbc-groovy-amd64", "vm-groovy-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_codbc_buster_amd64= build_linux_connector_odbc("codbc-buster-amd64", "vm-buster-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_codbc_fedora32_amd64= build_linux_connector_odbc("codbc-fedora32-amd64", "vm-fedora32-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_codbc_fedora33_amd64= build_linux_connector_odbc("codbc-fedora33-amd64", "vm-fedora33-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_codbc_sles12_amd64= build_linux_connector_odbc("codbc-sles12-amd64", "vm-sles123-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");

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
""" + (""" sudo yum --disablerepo=epel -y install unixODBC
sudo yum -y install unixODBC-devel
""" if yum else """#sudo apt-get update
sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get install --allow-unauthenticated -y --force-yes -m unixodbc-dev"
sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get install --allow-unauthenticated -y --force-yes -m openssl libssl-dev"
""") + """export CFLAGS="${CFLAGS}"""+ cflags + """"
time git clone --depth 1 -b %(branch)s "https://github.com/MariaDB/mariadb-connector-odbc.git" build
[-z "%(revision)s"] && git checkout %(revision)s
cd build
rm -rf ./test
git submodule init
git submodule update
cd libmariadb
git fetch --all --tags --prune
#git checkout """+ tag + """
git log | head -n5
cd ..
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCONC_WITH_UNIT_TESTS=Off -DPACKAGE_PLATFORM_SUFFIX=$HOSTNAME -DWITH_UNIT_TESTS=Off""" + cmake_params + """ .
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
bld_linux_x64_connector_odbc= bld_linux_connector_odbc("linux_x64-connector-odbc", "vm-centos6-amd64", "", True, "connector_c_2.3", " -DWITH_OPENSSL=OFF -DSYSTEM_NAME=rhel6 ", "v_2.3.7");
bld_linux_x86_connector_odbc= bld_linux_connector_odbc("linux_x86-connector-odbc", "vm-centos6-i386", "", True, "connector_c_2.3", " -DWITH_OPENSSL=OFF -DSYSTEM_NAME=rhel6 ", "v_2.3.7");
bld_centos7_x64_connector_odbc= bld_linux_connector_odbc("centos7_x64-connector-odbc", "vm-centos7-amd64", "", True, "connector_c_2.3", " -DWITH_OPENSSL=OFF -DSYSTEM_NAME=rhel7 ", "v_2.3.7");

bld_generic_x86_connector_odbc= bld_linux_connector_odbc("generic_x86-connector-odbc", "vm-centos5-i386", " -D_GNU_SOURCE", True, "connector_c_2.3", " -DWITH_OPENSSL=OFF ", "v_2.3.7");
bld_generic_x64_connector_odbc= bld_linux_connector_odbc("generic_x64-connector-odbc", "vm-centos5-amd64", " -D_GNU_SOURCE", True, "connector_c_2.3", " -DWITH_OPENSSL=OFF ", "v_2.3.7");
#################$### Current GA/stable version builders - END ###################

######################## New (unstable) version builders ######################
bld_linux_x64_connector_odbc_new= bld_linux_connector_odbc("linux_x64-connector-odbc-new", "vm-centos6-amd64", "", True, "3.0", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=rhel6 ", "v3.1.7");
bld_linux_x86_connector_odbc_new= bld_linux_connector_odbc("linux_x86-connector-odbc-new", "vm-centos6-i386", "", True, "3.0", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=rhel6 ", "v3.1.7");
bld_centos7_x64_connector_odbc_new= bld_linux_connector_odbc("centos7_x64-connector-odbc-new", "vm-centos7-amd64", "", True, "3.0", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=rhel7 ", "v3.1.7");
bld_centos8_x64_connector_odbc= bld_linux_connector_odbc("centos8_x64-connector-odbc", "vm-centos8-amd64", "", True, "3.0", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=rhel8 ", "v3.1.7");

bld_stretch_x64_connector_odbc= bld_linux_connector_odbc("stretch_x64-connector-odbc", "vm-stretch-amd64", "", False, "3.0", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=debian9 ", "v3.1.7");

bld_generic_x86_connector_odbc_new= bld_linux_connector_odbc("generic_x86-connector-odbc-new", "vm-centos5-i386", " -D_GNU_SOURCE", True, "3.0", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON ", "v3.1.7");
bld_generic_x64_connector_odbc_new= bld_linux_connector_odbc("generic_x64-connector-odbc-new", "vm-centos5-amd64", " -D_GNU_SOURCE", True, "3.0", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON ", "v3.1.7");
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
#sudo yum -y install unixODBC.x86_64
sudo yum -y install unixODBC.i686
#sudo yum -y install unixODBC-devel.x86_64
sudo yum -y install unixODBC-devel.i686
#sudo yum -y install zlib.x86_64
sudo yum -y install glibc-devel.i686 libstdc++-devel.i686 zlib.i686
#sudo yum -y install glibc-devel.x86_64 libstdc++-devel.x86_64
sudo yum -y install openssl-devel.i686
#sudo yum -y install openssl-devel.x86_64
sudo yum -y install libcom_err.i686
#sudo yum -y install libcom_err.x86_64
sudo ldconfig
time git clone --depth 1 -b %(branch)s "https://github.com/MariaDB/mariadb-connector-odbc.git" build
cd build
rm -rf ./test
git submodule init
git submodule update
cd libmariadb
git fetch --all --tags --prune
#git checkout """+ tag + """
git log | head -n5
cd ..
setarch i386 cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DPACKAGE_PLATFORM_SUFFIX=$HOSTNAME -DWITH_UNIT_TESTS=Off """ + cmake_params + """ -DCMAKE_TOOLCHAIN_FILE=cmake/linux_x86_toolchain.cmake .
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

bld_centos7_x86_connector_odbc= bld_xcomp_linux_connector_odbc("centos7_x86-connector-odbc", "vm-centos7-amd64", "connector_c_2.3", " -DWITH_OPENSSL=OFF -DSYSTEM_NAME=rhel7 ", "v_2.3.7");
bld_centos7_x86_connector_odbc_new= bld_xcomp_linux_connector_odbc("centos7_x86-connector-odbc-new", "vm-centos7-amd64", "3.0", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=rhel7 ", "v3.1.7");
bld_centos8_x86_connector_odbc= bld_xcomp_linux_connector_odbc("centos8_x86-connector-odbc", "vm-centos8-amd64", "3.0", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=rhel7 ", "v3.1.7");

