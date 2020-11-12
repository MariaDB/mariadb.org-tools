
################################# bld_linux_connector_oddbc ################################
def build_src_connector_cpp(name, kvm_image):
    f_src_connector_cpp= BuildFactory()
    args= ["--port="+getport(), "--user=buildbot", "--smp=4", "--cpu=qemu64"]
    f_src_connector_cpp.addStep(ShellCommand(
        description=["cleaning", "build", "dir"],
        descriptionDone=["clean", "build", "dir"],
        command=["sh", "-c", "rm -Rf ../build/*"]))
    f_src_connector_cpp.addStep(ShellCommand(
        description=["rsyncing", "VMs"],
        descriptionDone=["rsync", "VMs"],
        doStepIf=(lambda(step): step.getProperty("slavename") != "bb01"),
        haltOnFailure=True,
        command=["rsync", "-a", "-v", "-L",
                 "bb01.mariadb.net::kvm/vms/"+kvm_image+"-build.qcow2",
                 "/kvm/vms/"]))
    f_src_connector_cpp.addStep(Compile(
        description=["building", "linux-connctor_cpp"],
        descriptionDone=["build", "linux-connector_cpp"],
        timeout=3600,
        env={"TERM": "vt102"},
        command=["runvm", "--base-image=/kvm/vms/"+kvm_image+"-build.qcow2"] + args +["vm-tmp-"+getport()+".qcow2",
        "rm -Rf buildbot && mkdir buildbot",
        WithProperties("""
set -ex
git --version
rm -Rf build
time git clone --depth 1 -b %(branch)s "https://github.com/mariadb-corporation/mariadb-connector-cpp.git" build
cd build
git reset --hard %(revision)s
rm -rf ./test
rm -rf ./libmariadb
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_OPENSSL=OFF -DGIT_BUILD_SRCPKG=1 .
ls -l ./mariadb*cpp*src*tar.gz ./mariadb*cpp*src*.zip
tar ztf ./mariadb*src*tar.gz
"""),
        "= scp -r -P "+getport()+" "+kvm_scpopt+" buildbot@localhost:/home/buildbot/build/mariadb*cpp*src*.* .",
        ]))
#make package_source
    f_src_connector_cpp.addStep(SetPropertyFromCommand(
        property="src_pack_name",
        command=["sh", "-c", WithProperties("basename `ls mariadb*cpp*src*tar.gz`")],
        ))
    addPackageUploadStep(f_src_connector_cpp, '"%(src_pack_name)s"')
    f_src_connector_cpp.addStep(SetPropertyFromCommand(
        property="src_pack_name",
        command=["sh", "-c", WithProperties("basename `ls mariadb*cpp*src*.zip`")],
        ))
    addPackageUploadStep(f_src_connector_cpp, '"%(src_pack_name)s"')
    return {'name': name, 'builddir': name,
            'factory': f_src_connector_cpp,
            "slavenames": connector_slaves,
            "category": "connectors"}

bld_src_connector_cpp= build_src_connector_cpp("src_connector_cpp", "vm-stretch-amd64");
