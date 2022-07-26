
################################# bld_linux_connector_oddbc ################################

conncpp_linux_step0_checkout= step0_checkout("https://github.com/MariaDB-Corporation/mariadb-connector-cpp.git") + step0_set_test_env
conncpp_linux_step1_build= step1_build
conncpp_linux_step2_serverinstall= linux_serverinstall
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
conncpp_linux_step4_testsrun= step4_testsrun

def bld_linux_connector_cpp(name, kvm_image, cflags, cmake_params):
    linux_connector_cpp= BuildFactory()
    args= ["--port="+getport(), "--user=buildbot", "--smp=4", "--cpu=host"]
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
######################## bld_linux_connector_cpp - END #####################

######################## "Normal" builders ######################
bld_rhel9_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-rhel9-amd64", "vm-rhel9-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON ");
bld_rhel8_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-rhel8-amd64", "vm-rhel8-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON ");
bld_centos8_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-centos8-amd64", "vm-rhel8-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON ");

bld_sles15_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-sles15-amd64", "vm-sles153-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");

bld_bionic_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-bionic-amd64", "vm-bionic-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_focal_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-focal-amd64", "vm-focal-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");

bld_jammy_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-jammy-amd64", "vm-jammy-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");

bld_buster_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-buster-amd64", "vm-buster-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_bullseye_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-bullseye-amd64", "vm-bullseye-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");

bld_fedora34_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-fedora34-amd64", "vm-fedora34-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_fedora35_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-fedora35-amd64", "vm-fedora35-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");
bld_fedora36_amd64_connector_cpp= bld_linux_connector_cpp("ccpp-fedora36-amd64", "vm-fedora36-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");

##################### Building with the hack for platforms with old gcc ##################

def bld_linux_connector_cpp_with_hack(name, kvm_image, cflags, cmake_params):
    linux_connector_cpp= BuildFactory()
    args= ["--port="+getport(), "--user=buildbot", "--smp=4", "--cpu=host"]
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

##################### Building with gcc-5 for platforms with >1 gcc installed, and default is too old  ##################

def bld_linux_connector_cpp_with_gcc5(name, kvm_image, cflags, cmake_params):
    linux_connector_cpp= BuildFactory()
    args= ["--port="+getport(), "--user=buildbot", "--smp=4", "--cpu=host"]
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
export CC=/usr/bin/gcc-5
export CXX=/usr/bin/g++-5
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

bld_sles12_amd64_connector_cpp= bld_linux_connector_cpp_with_gcc5("ccpp-sles12-amd64", "vm-sles125-amd64", "", " -DWITH_SSL=OPENSSL -DWITH_OPENSSL=ON");

