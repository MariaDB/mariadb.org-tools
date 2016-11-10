f_valgrind = factory.BuildFactory()

f_valgrind.addStep(ShellCommand(
    description=["cleaning", "build", "dir"],
    descriptionDone=["clean", "build", "dir"],
    command=["sh", "-c", "rm -Rf ../build/*"]))

f_valgrind.addStep(ShellCommand(
    description=["rsyncing", "VMs"],
    descriptionDone=["rsync", "VMs"],
    doStepIf=(lambda(step): step.getProperty("slavename") != "bb01"),
    haltOnFailure=True,
    command=["rsync", "-a", "-v", "-L",
             "bb01.mariadb.net::kvm/vms/vm-xenial-amd64-valgrind.qcow2",
             "/kvm/vms/"]))
f_valgrind.addStep(DownloadSourceTarball())
# Extract the compiler warning suppressions file from the source tarball.
f_valgrind.addStep(ShellCommand(
    description=["getting", ".supp"],
    descriptionDone=["get", ".supp"],
    command=["sh", "-c", WithProperties("""
rm -f compiler_warnings.supp
tar zxf "/tmp/buildcache/%(tarbuildnum)s:%(distname)s" --strip 2 "$(basename %(distname)s .tar.gz)/support-files/compiler_warnings.supp"
exit 0  # best-effort, not fatal if no suppression file
""")]))
f_valgrind.addStep(Compile(
    description=["compiling", "and", "running", "tests"],
    descriptionDone=["compile", "and", "run", "tests"],
    logfiles={"kernel": "kernel_10710.log"},
    warningPattern=gccWarningPattern,
    warningExtractor=Compile.warnExtractFromRegexpGroups,
    suppressionFile=WithProperties("compiler_warnings.supp"),
    timeout=3600,
    env={"TERM": "vt102"},
    command=["runvm", "--base-image=/kvm/vms/vm-xenial-amd64-valgrind.qcow2", "--port=2331", "--user=buildbot", "--smp=4", "--cpu=qemu64", "--startup-timeout=600", "--logfile=kernel_2331.log", "vm-tmp-build-2331.qcow2",
    "rm -Rf buildbot && mkdir buildbot",
    ScpSourceIntoVM("2331"),
    WithProperties("""
set -ex
rm -Rf build
tar zxf "buildbot/%(distname)s"
mv "%(distdirname)s" build
cd build
cmake . -DCMAKE_BUILD_TYPE=Debug -DWITH_VALGRIND=1
make -j3
cd mysql-test
MTR_FEEDBACK_PLUGIN=1 perl mysql-test-run.pl  --verbose-restart --mem --parallel=2 --valgrind --valgrind-option=--show-reachable=yes --valgrind-option=--gen-suppressions=all --force --retry=3  --max-test-fail=100 --max-save-core=0 --max-save-datadir=1 --suite=main
"""),
    ]))

bld_xenial_valgrind = {'name': "xenial-amd64-valgrind",
                'slavenames': [ "bb02", "bb03", "bb04" ],
                'builddir': "xenial-amd64-valgrind",
                'factory': f_valgrind,
                "nextBuild": myNextBuild,
                "category": "experimental",
                }
