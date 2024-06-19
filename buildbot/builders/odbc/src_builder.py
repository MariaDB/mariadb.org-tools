
################################# bld_linux_connector_oddbc ################################
def build_src_connector_odbc(name, kvm_image):
    f_src_connector_odbc= BuildFactory()
    args= ["--port="+getport(), "--user=buildbot", "--smp=4", "--cpu=qemu64"]
    f_src_connector_odbc.addStep(ShellCommand(
        description=["cleaning", "build", "dir"],
        descriptionDone=["clean", "build", "dir"],
        command=["sh", "-c", "rm -Rf ../build/*"]))
    f_src_connector_odbc.addStep(ShellCommand(
        description=["rsyncing", "VMs"],
        descriptionDone=["rsync", "VMs"],
        doStepIf=(lambda(step): step.getProperty("slavename") != "bb01"),
        haltOnFailure=True,
        command=["rsync", "-a", "-v", "-L",
                 "bb01.mariadb.net::kvm/vms/"+kvm_image+"-build.qcow2",
                 "/kvm/vms/"]))
    f_src_connector_odbc.addStep(Compile(
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
rm -Rf cc

CCINSTDIR="${PWD}/cc"
time git clone --depth 1 -b %(branch)s "https://github.com/MariaDB-Corporation/mariadb-connector-odbc.git" build
cd build
git reset --hard %(revision)s
rm -rf ./test

# Building and installing C/C to test build from source and against C/C installation
# Directory for C/C installtaion
mkdir ../cc
git submodule init
git submodule update
cd libmariadb
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_SSL=OPENSSL -DWITH_UNIT_TESTS=Off -DCMAKE_INSTALL_PREFIX=$CCINSTDIR .
make
make install
cd ..
ls $CCINSTDIR
echo $LIBRARY_PATH
echo $CPATH
export LIBRARY_PATH="${LIBRARY_PATH}:${CCINSTDIR}/lib:${CCINSTDIR}/lib/mariadb"
export CPATH="${CPATH}:${CCINSTDIR}/include:${CCINSTDIR}/include/mariadb"
# We need it deleted for source package generation
rm -rf ./libmariadb
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_OPENSSL=OFF -DGIT_BUILD_SRCPKG=1 .
ls -l ./mariadb*odbc*src*tar.gz ./mariadb*odbc*src*.zip
SRC_PACK_NAME=`ls ./mariadb*src*tar.gz`
tar ztf $SRC_PACK_NAME
cd ..
tar zxf build/$SRC_PACK_NAME
ls
cd mariadb*src*
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_OPENSSL=OFF -DCONC_WITH_UNIT_TESTS=Off -DWITH_UNIT_TESTS=Off -DMARIADB_LINK_DYNAMIC=1 .
make
"""),
        "= scp -r -P "+getport()+" "+kvm_scpopt+" buildbot@localhost:/home/buildbot/build/mariadb*odbc*src*.* .",
        ]))
#make package_source
    f_src_connector_odbc.addStep(SetPropertyFromCommand(
        property="src_pack_name",
        command=["sh", "-c", WithProperties("basename `ls mariadb*odbc*src*tar.gz`")],
        ))
    addPackageUploadStep(f_src_connector_odbc, '"%(src_pack_name)s"')
    f_src_connector_odbc.addStep(SetPropertyFromCommand(
        property="src_pack_name",
        command=["sh", "-c", WithProperties("basename `ls mariadb*odbc*src*.zip`")],
        ))
    addPackageUploadStep(f_src_connector_odbc, '"%(src_pack_name)s"')
    return {'name': name, 'builddir': name,
            'factory': f_src_connector_odbc,
            "slavenames": connector_slaves,
            "category": "connectors"}

bld_codbc_src= build_src_connector_odbc("codbc-source-package", "vm-buster-amd64");
#sudo apt-get update
#sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get install --allow-unauthenticated -y --force-yes -m unixodbc-dev"


