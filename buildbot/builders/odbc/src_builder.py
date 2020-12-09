
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
time git clone --depth 1 -b %(branch)s "https://github.com/MariaDB/mariadb-connector-odbc.git" build
cd build
git reset --hard %(revision)s
rm -rf ./test
rm -rf ./libmariadb
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_OPENSSL=OFF -DGIT_BUILD_SRCPKG=1 .
ls -l ./mariadb*odbc*src*tar.gz ./mariadb*odbc*src*.zip
tar ztf ./mariadb*src*tar.gz
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

bld_src_connector_odbc= build_src_connector_odbc("codbc-source-package", "vm-buster-amd64");
#sudo apt-get update
#sudo sh -c "DEBIAN_FRONTEND=noninteractive apt-get install --allow-unauthenticated -y --force-yes -m unixodbc-dev"


