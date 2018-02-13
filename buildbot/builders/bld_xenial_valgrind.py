def isValgrindTree(step):
  return step.getProperty("branch") in [ "bb-10.0-elenst" ]

f_valgrind = BuildFactory()

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
             "bb01.mariadb.net::kvm/vms/vm-centos74-amd64-serial.qcow2",
             "bb01.mariadb.net::kvm/vms/vm-centos74-amd64-valgrind.qcow2",
             "/kvm/vms/"]))

f_valgrind.addStep(ShellCommand(
    description=["checking", "VMs"],
    descriptionDone=["check", "VMs"],
#    haltOnFailure=True,
    command=["ls", "-la",
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
    description=["compiling"],
    descriptionDone=["compile"],
    logfiles={"kernel": "kernel_"+getport()+".log"},
    warningPattern=gccWarningPattern,
    warningExtractor=Compile.warnExtractFromRegexpGroups,
    suppressionFile=WithProperties("compiler_warnings.supp"),
    timeout=3600,
    env={"TERM": "vt102", "EXTRA_FLAGS": "-O3 -fno-omit-frame-pointer -Wno-uninitialized -fno-strict-aliasing", "AM_EXTRA_MAKEFLAGS": "VERBOSE=1"},
    command=["runvm", "--base-image=/kvm/vms/vm-centos74-amd64-valgrind.qcow2", "--port="+getport(), "--user=buildbot", "--smp=4", "--mem=6144",
    "--cpu=qemu64", "--startup-timeout=600", "--logfile=kernel_"+getport()+".log", "vm-tmp-build-"+getport()+".qcow2",
    "rm -Rf buildbot && mkdir buildbot",
    ScpSourceIntoVM(),
    WithProperties("""
set -ex
rm -Rf build
tar zxf "buildbot/%(distname)s"
mv "%(distdirname)s" build
cd build
cmake . -DCMAKE_BUILD_TYPE=Debug -DWITH_VALGRIND=1
make -j6
"""),
    ]))

f_valgrind.addStep(getMTR(
#    doStepIf=isMainTree,
    test_type="default",
    test_info="Valgrind run, no --ps-protocol",
    timeout=9600,
    mtr_subdir=".",
    env={"TERM": "vt102","MTR_FEEDBACK_PLUGIN": "1"},
    command=["runvm", "--base-image=vm-tmp-build-"+getport()+".qcow2", "--port="+getport(), "--user=buildbot", "--smp=4", "--mem=6144",
        "--cpu=qemu64", "--startup-timeout=600", "--logfile=kernel_"+getport()+".log", "vm-tmp-"+getport()+".qcow2",
    WithProperties("""
set -ex
cd build/mysql-test

# Choose which suites and tests to skip

# SUITES variable will contain --suites=suite1,suite2,... or  it will be empty
# if all main suites should be run

# SKIP_TESTS variable will contain --skip-test="pattern1|pattern2|..."

# Configuring SUITES first

case "%(branch)s" in

*-valgrind-* | *-elenst-* | bb-10.0-vicentiu)
  # TODO: remove this when everything is polished
  # Run all default suites
  SUITES=
  ;;
bb-*)
  # TODO: remove this when everything is polished
  # For non-main trees, only run the main suite for now
  SUITES=main
  ;;
*)
  # For main trees, all default suites should be run
  # (but some might be skipped via SKIP_TESTS)
  SUITES=
  ;;
esac

# TODO: Make it better
SUITES=main

# Configuring SKIP_TESTS

# For all branches, lets skip some TokuDB suites, as they are too long:

SKIP_TESTS='--skip-test=^tokudb\.|^tokudb_alter_table\.|^tokudb_bugs\.|^rpl-tokudb\.|^tokudb_add_index\.'

# Due to MDEV-11686, disabling encryption tests

SKIP_TESTS=$SKIP_TESTS'|encryption\.'

# Due to MDEV-11700, temporarily disabling funcs_2.innodb_charset test

SKIP_TESTS=$SKIP_TESTS'|funcs_2\.innodb_charset'

# Experimentally disabling some other very slow tests 
# TODO: (if it turns out to be okay,
# maybe they should be disabled in a way similar to MDEV-11700)

SKIP_TESTS=$SKIP_TESTS'|main\.selectivity_innodb|main\.index_merge_innodb|main\.stat_tables_innodb|main\.stat_tables_par_innodb|main\.innodb_ext_key|main\.range_vs_index_merge_innodb|main\.stat_tables_disabled|percona\.percona_xtradb_bug317074|innodb\.innodb\-page_compression_lzma|innodb\.innodb\-page_compression_zip|innodb\.innodb_bug30423|innodb_fts\.innodb_fts_misc'

case "%(branch)s" in

*5.5*)
  # Due to MDEV-11718, disabling rpl and federated tests for 5.5-based trees.
  # It might be a bit excessive, but hopefully it's a temporary measure
  SKIP_TESTS=$SKIP_TESTS'|^rpl\.|^federated\.'
  ;;
*)
  ;;
esac

# Suite list: $SUITES
# Skip list: $SKIP_TESTS

if perl mysql-test-run.pl  --verbose-restart --vardir="$(readlink -f /dev/shm/var)" --valgrind --valgrind-option=--show-reachable=yes --force --max-test-fail=100 --max-save-core=0 --max-save-datadir=1 --parallel=4 $SUITES $SKIP_TESTS
then
  exit 0
else
# On whatever reason, on some systems, xenial included, we can't scp vardir directly from /dev/shm,
# it claims to be non-existant, while on others it works.
# So, we'll move it here first, and in the next command will scp from here.
# Maybe there are better ways to do the same, but as of today, this works at least
  rm -rf var
  mv /dev/shm/var ./
  exit 1
fi
"""),
   WithProperties(
     "!= rm -Rf var/ ; scp -rp -P "+getport()+" " + kvm_scpopt +
     " buildbot@localhost:~buildbot/build/mysql-test/var . || :")
    ],
    parallel=4))

bld_vm_valgrind = {'name': "vm-amd64-valgrind",
                'slavenames': [ "bbm5" ],
                'builddir': "vm-amd64-valgrind",
                'factory': f_valgrind,
                "nextBuild": myNextBuild,
                "category": "experimental",
                }
