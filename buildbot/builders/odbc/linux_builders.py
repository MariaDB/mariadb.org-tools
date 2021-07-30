# The default build steps used here are defined in the builders/connectors-buildsteps.py
connodbc_linux_step0_checkout= step0_checkout("https://github.com/MariaDB-Corporation/mariadb-connector-odbc.git") + """
export TEST_DRIVER=maodbc_test
export TEST_DSN=maodbc_test
"""
connodbc_linux_step1_build= step1_build
connodbc_linux_step2_serverinstall= linux_serverinstall
#Step 3 - package quality test step - to add
connodbc_linux_step3_packagetest= ""
connodbc_linux_step4_testsrun= """cd ./build/test
cat odbcinst.ini
cat odbc.ini
export ODBCINI="$PWD/odbc.ini"
export ODBCSYSINI=$PWD
export TEST_SKIP_UNSTABLE_TEST=1
cd ../..
""" + step4_testsrun

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
export CFLAGS="${CFLAGS}"""+ cflags + """" """ +
connodbc_linux_step0_checkout + """
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCONC_WITH_UNIT_TESTS=Off -DPACKAGE_PLATFORM_SUFFIX=$HOSTNAME""" + cmake_params + """ ../src""" +
connodbc_linux_step1_build +
connodbc_linux_step2_serverinstall +
connodbc_linux_step3_packagetest +
connodbc_linux_step4_testsrun
),
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

bld_codbc_bionic_amd64= build_linux_connector_odbc("codbc-bionic-amd64", "vm-bionic-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_codbc_focal_amd64= build_linux_connector_odbc("codbc-focal-amd64", "vm-focal-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_codbc_groovy_amd64= build_linux_connector_odbc("codbc-groovy-amd64", "vm-groovy-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_codbc_hirsute_amd64= build_linux_connector_odbc("codbc-hirsute-amd64", "vm-hirsute-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_codbc_buster_amd64= build_linux_connector_odbc("codbc-buster-amd64", "vm-buster-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_codbc_fedora33_amd64= build_linux_connector_odbc("codbc-fedora33-amd64", "vm-fedora33-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_codbc_fedora34_amd64= build_linux_connector_odbc("codbc-fedora34-amd64", "vm-fedora34-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_codbc_sles12_amd64= build_linux_connector_odbc("codbc-sles12-amd64", "vm-sles123-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_centos7_x64_connector_odbc_new= build_linux_connector_odbc("codbc-centos7-amd64", "vm-centos7-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_centos8_x64_connector_odbc= build_linux_connector_odbc("codbc-centos8-amd64", "vm-centos8-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_stretch_x64_connector_odbc= build_linux_connector_odbc("codbc-stretch-amd64", "vm-stretch-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");

######################## New (unstable) version builders ######################


##################### New (unstable) version builders - END ###################

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

######################## Old 2.0 builder ######################
#bld_linux_x64_connector_odbc= bld_linux_connector_odbc("linux_x64-connector-odbc", "vm-centos6-amd64", "", True, "connector_c_2.3", " -DWITH_OPENSSL=OFF -DSYSTEM_NAME=rhel6 ", "v_2.3.7");



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

#bld_centos7_x86_connector_odbc= bld_xcomp_linux_connector_odbc("centos7_x86-connector-odbc", "vm-centos7-amd64", "connector_c_2.3", " -DWITH_OPENSSL=OFF -DSYSTEM_NAME=rhel7 ", "v_2.3.7");
bld_centos7_x86_connector_odbc_new= bld_xcomp_linux_connector_odbc("codbc-centos7-x86", "vm-centos7-amd64", "3.0", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=rhel7 ", "v3.1.7");
bld_centos8_x86_connector_odbc= bld_xcomp_linux_connector_odbc("codbc-centos8-x86", "vm-centos8-amd64", "3.0", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON -DSYSTEM_NAME=rhel7 ", "v3.1.7");

