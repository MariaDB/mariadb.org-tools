###############################################################################################
#
# "QA" tests (as opposed to normal dev builders)

f_qa_linux = factory.BuildFactory()

f_qa_linux.addStep(ShellCommand(
    description=["cleaning", "build", "dir"],
    descriptionDone=["clean", "build", "dir"],
    command=["sh", "-c", "rm -Rf ../build/*"]))
f_qa_linux.addStep(ShellCommand(
    description=["rsyncing", "VMs"],
    descriptionDone=["rsync", "VMs"],
    doStepIf=(lambda(step): step.getProperty("slavename") != "bb01"),
    haltOnFailure=True,
    command=["rsync", "-a", "-v", "-L",
             "bb01.mariadb.net::kvm/vms/vm-jessie-qa.qcow2",
             "/kvm/vms/"]))
f_qa_linux.addStep(DownloadSourceTarball())
# Extract the compiler warning suppressions file from the source tarball.
f_qa_linux.addStep(ShellCommand(
    doStepIf=(lambda(step): branch_is_10_x(step) and branch_is_not_10_3(step)),
    description=["getting", ".supp"],
    descriptionDone=["get", ".supp"],
    command=["sh", "-c", WithProperties("""
rm -f compiler_warnings.supp
tar zxf "/tmp/buildcache/%(tarbuildnum)s:%(distname)s" --strip 2 "$(basename %(distname)s .tar.gz)/support-files/compiler_warnings.supp"
exit 0  # best-effort, not fatal if no suppression file
""")]))
f_qa_linux.addStep(Compile(
    description=["compiling", "and", "updating", "git", "trees"],
    descriptionDone=["compile", "and", "git", "update"],
    logfiles={"kernel": "kernel_10710.log"},
    warningPattern=gccWarningPattern,
    warningExtractor=Compile.warnExtractFromRegexpGroups,
    suppressionFile=WithProperties("compiler_warnings.supp"),
    timeout=3600,
    env={"TERM": "vt102"},
    command=["runvm", "--base-image=/kvm/vms/vm-jessie-qa.qcow2", "--port=10710", "--user=buildbot", "--smp=4", "--cpu=qemu64", "--startup-timeout=600", "--logfile=kernel_10710.log", "vm-tmp-build-10710.qcow2",
    "rm -Rf buildbot && mkdir buildbot",
    ScpSourceIntoVM("10710"),
    WithProperties("""
set -ex
rm -Rf build
tar zxf "buildbot/%(distname)s"
mv "%(distdirname)s" build
cd build
cmake . -DCMAKE_BUILD_TYPE=Debug -DPLUGIN_AWS_KEY_MANAGEMENT=NO
make -j4
. /home/buildbot/mariadb-toolbox/scripts/create_so_symlinks.sh
cd /home/buildbot/rqg
git pull
cd /home/buildbot/mariadb-toolbox
git pull
"""),
    ]))
f_qa_linux.addStep(Test(
    doStepIf=False,
    name="gtid_stress",
    description=["GTID-based replication"],
    descriptionDone=["GTID-based replication"],
    timeout=3600,
    env={"TERM": "vt102"},
    command=["runvm", "--base-image=vm-tmp-build-10710.qcow2", "--port=10710", "--user=buildbot", "--smp=4", "--cpu=qemu64", "--startup-timeout=600", "--logfile=kernel_10710.log", "vm-tmp-10710.qcow2",
    WithProperties("""
set -ex
cd rqg
perl ./runall-new.pl --grammar=conf/mariadb/gtid_stress.yy --gendata=conf/mariadb/gtid_stress.zz --duration=600 --threads=8 --queries=100M --rpl_mode=mixed --use_gtid=current_pos --basedir=/home/buildbot/build --vardir=/home/buildbot/vardir_gtid
echo "----------------------------------------------"
echo "Master log"
echo "----------------------------------------------"
grep -v 'InnoDB: DEBUG' /home/buildbot/vardir_gtid/mysql.err | grep -v '\[Note\]'
echo "----------------------------------------------"
echo "Slave log"
echo "----------------------------------------------"
grep -v 'InnoDB: DEBUG' /home/buildbot/vardir_gtid_slave/mysql.err | grep -v '\[Note\]'
"""),
    ]))

f_qa_linux.addStep(Test(
    doStepIf=(lambda(step): branch_is_10_x(step)),
    name="upgr_10.0",
    description=["Upgrade from 10.0"],
    descriptionDone=["Upgrade from 10.0"],
    timeout=3600,
    env={"TERM": "vt102", "BUILD_HOME": "/home/buildbot"},
    command=["runvm", "--base-image=vm-tmp-build-10710.qcow2", "--port=10710", "--user=buildbot", "--smp=4", "--cpu=qemu64", "--startup-timeout=600", "--logfile=kernel_10710.log", "vm-tmp-10710.qcow2",
    WithProperties("""
set -ex
cd rqg
export BUILD_HOME=/home/buildbot

case "%(branch)s" in
*10.0*)
  config=bb-upgrade-10.0-to-10.0-small.cc
  ;;
*10.1*)
  config=bb-upgrade-10.0-to-10.1-small.cc
  ;;
*)
  config=bb-upgrade-from-10.0-small.cc
  ;;
esac

if perl ./combinations.pl --new --config=/home/buildbot/mariadb-toolbox/configs/$config --run-all-combinations-once --force --workdir=/home/buildbot/upgrade-from-10.0
then
  res=0
else
  res=1
fi
perl /home/buildbot/mariadb-toolbox/scripts/parse_upgrade_logs.pl --mode=jira /home/buildbot/upgrade-from-10.0/trial*
perl /home/buildbot/mariadb-toolbox/scripts/parse_upgrade_logs.pl --mode=text /home/buildbot/upgrade-from-10.0/trial*
exit $res
"""),
    ]))

f_qa_linux.addStep(Test(
    doStepIf=(lambda(step): branch_is_10_1_or_later(step)),
    name="upgr_5.6",
    description=["Upgrade from MySQL 5.6"],
    descriptionDone=["Upgrade from MySQL 5.6"],
    timeout=3600,
    env={"TERM": "vt102", "BUILD_HOME": "/home/buildbot"},
    command=["runvm", "--base-image=vm-tmp-build-10710.qcow2", "--port=10710", "--user=buildbot", "--smp=4", "--cpu=qemu64", "--startup-timeout=600", "--logfile=kernel_10710.log", "vm-tmp-10710.qcow2",
    WithProperties("""
set -ex
cd rqg
export BUILD_HOME=/home/buildbot

case "%(branch)s" in
*10.0*|*10.1*)
  config=bb-upgrade-mysql-5.6-to-10.1-small.cc
  ;;
*)
  config=bb-upgrade-from-mysql-5.6-small.cc
  ;;
esac

if perl ./combinations.pl --new --config=/home/buildbot/mariadb-toolbox/configs/$config --run-all-combinations-once --force --workdir=/home/buildbot/upgrade-from-mysql-5.6
then
  res=0
else
  res=1
fi
perl /home/buildbot/mariadb-toolbox/scripts/parse_upgrade_logs.pl --mode=jira /home/buildbot/upgrade-from-mysql-5.6/trial*
perl /home/buildbot/mariadb-toolbox/scripts/parse_upgrade_logs.pl --mode=text /home/buildbot/upgrade-from-mysql-5.6/trial*
exit $res
"""),
    ]))


f_qa_linux.addStep(Test(
    doStepIf=(lambda(step): branch_is_10_1_or_later(step)),
    name="upgr_10_1",
    description=["Upgrade from 10.1"],
    descriptionDone=["Upgrade from 10.1"],
    timeout=3600,
    env={"TERM": "vt102", "BUILD_HOME": "/home/buildbot"},
    command=["runvm", "--base-image=vm-tmp-build-10710.qcow2", "--port=10710", "--user=buildbot", "--smp=4", "--cpu=qemu64", "--startup-timeout=600", "--logfile=kernel_10710.log", "vm-tmp-10710.qcow2",
    WithProperties("""
set -ex
cd rqg
export BUILD_HOME=/home/buildbot

case "%(branch)s" in
*10.1*)
  config=bb-upgrade-10.1-to-10.1-small.cc
  ;;
*)
  config=bb-upgrade-from-10.1-small.cc
  ;;
esac

if perl ./combinations.pl --new --config=/home/buildbot/mariadb-toolbox/configs/$config --run-all-combinations-once --force --workdir=/home/buildbot/upgrade-from-10.1
then
  res=0
else
  res=1
fi
perl /home/buildbot/mariadb-toolbox/scripts/parse_upgrade_logs.pl --mode=jira /home/buildbot/upgrade-from-10.1/trial*
perl /home/buildbot/mariadb-toolbox/scripts/parse_upgrade_logs.pl --mode=text /home/buildbot/upgrade-from-10.1/trial*
exit $res
"""),
    ]))

f_qa_linux.addStep(Test(
    doStepIf=(lambda(step): branch_is_10_2_or_later(step)),
    name="upgr_5.7",
    description=["Upgrade from MySQL 5.7"],
    descriptionDone=["Upgrade from MySQL 5.7"],
    timeout=3600,
    env={"TERM": "vt102", "BUILD_HOME": "/home/buildbot"},
    command=["runvm", "--base-image=vm-tmp-build-10710.qcow2", "--port=10710", "--user=buildbot", "--smp=4", "--cpu=qemu64", "--startup-timeout=600", "--logfile=kernel_10710.log", "vm-tmp-10710.qcow2",
    WithProperties("""
set -ex
cd rqg
export BUILD_HOME=/home/buildbot
if perl ./combinations.pl --new --config=/home/buildbot/mariadb-toolbox/configs/bb-upgrade-from-mysql-5.7-small.cc --run-all-combinations-once --force --workdir=/home/buildbot/upgrade-from-mysql-5.7
then
  res=0
else
  res=1
fi
perl /home/buildbot/mariadb-toolbox/scripts/parse_upgrade_logs.pl --mode=jira /home/buildbot/upgrade-from-mysql-5.7/trial*
perl /home/buildbot/mariadb-toolbox/scripts/parse_upgrade_logs.pl --mode=text /home/buildbot/upgrade-from-mysql-5.7/trial*
exit $res
"""),
    ]))



f_qa_linux.addStep(Test(
#    doStepIf=(lambda(step): step.getProperty("branch") == "10.2"),
    doStepIf=False,
    name="rqg_10.2",
    description=["10.2 features"],
    descriptionDone=["10.2 features"],
    timeout=3600,
    env={"TERM": "vt102"},
    command=["runvm", "--base-image=vm-tmp-build-10710.qcow2", "--port=10710", "--user=buildbot", "--smp=4", "--cpu=qemu64", "--startup-timeout=600", "--logfile=kernel_10710.log", "vm-tmp-10710.qcow2",
    WithProperties("""
set -ex
cd rqg
perl ./combinations.pl --new --config=conf/mariadb/10.2-new-features.cc --run-all-combinations-once --force --basedir=/home/buildbot/build --workdir=/home/buildbot/10.2-features
"""),
    ]))

f_qa_linux.addStep(getMTR(
    doStepIf=(lambda(step): branch_is_10_x(step)),
    name="engines",
    test_type="engines",
    test_info="MySQL engines/* tests",
    timeout=7200,
    env={"TERM": "vt102"},
    command=["runvm", "--base-image=vm-tmp-build-10710.qcow2", "--port=10710", "--user=buildbot", "--smp=4", "--cpu=qemu64", "--startup-timeout=600", "--logfile=kernel_10710.log", "vm-tmp-10710.qcow2",
    WithProperties("""
set -ex
cd build/mysql-test
echo "See TODO-823 for explanation why open-files-limit and log-warnings are here"
perl mysql-test-run.pl  --verbose-restart --force --max-save-core=0 --max-save-datadir=1 --suite=engines/funcs,engines/iuds --parallel=4 --mysqld=--open-files-limit=0 --mysqld=--log-warnings=1 --mem --verbose-restart
"""),
    ]))

f_qa_linux.addStep(getMTR(
    doStepIf=(lambda(step): branch_is_10_x(step) and branch_is_not_10_3(step)),
    name="stable_tests",
    test_type="nm",
    test_info="Skip unstable tests",
    timeout=7200,
    env={"TERM": "vt102"},
    command=["runvm", "--base-image=vm-tmp-build-10710.qcow2", "--port=10710", "--user=buildbot", "--smp=4", "--cpu=qemu64", "--startup-timeout=600", "--logfile=kernel_10710.log", "vm-tmp-10710.qcow2",
    WithProperties("""
set -ex
cd build/mysql-test
perl mysql-test-run.pl  --verbose-restart --force --max-save-core=0 --max-save-datadir=1 --skip-test-list=unstable-tests --parallel=4 --mem --verbose-restart
"""),
    ]))

bld_kvm_qa_linux = {
        'name': "qa-kvm-linux",
        'slavenames': ["bb02","bb03","bb04","aidi"],
        'builddir': "kvm-qa-linux",
        'factory': f_qa_linux,
        "nextBuild": myNextBuild,
        'category': "experimental"
}

###############################################################################################
#
# RQG and storage engine tests on a Windows machine

from buildbot.steps.slave import RemoveDirectory

from buildbot import locks

# This is a very strong lock, it will be used if the builder cannot proceed without killing mysqld,
# and it will require waiting for all tests in other builder to finish
#kill_mysqld_lock = locks.SlaveLock("mysqld_kill_license")
git_rqg_lock = locks.SlaveLock("git_rqg");
#release_build_lock = locks.SlaveLock("release_build")
#debug_build_lock = locks.SlaveLock("debug_build")

def rqg_win_factory(mtr_build_thread="130",config="Debug"):

    if config=='Debug':
        do_debug_steps=True
        do_release_steps=False
    else:
        do_debug_steps=False
        do_release_steps=True

    f = factory.BuildFactory()

# We shouldn't need it anymore since we are setting appverif in runall.pl now, but let it be here just in case
    f.addStep(ShellCommand(
        name="disable_app_verifier",
        command=["dojob", "appverif", "/n", "mysqld.exe"],
        doStepIf=do_release_steps
    ));

    # that's where pre-cloned trees (mariadb-server, rqg, mariadb-toolbox etc.) and local scripts are
    f.addStep(SetPropertyFromCommand(
        name="set_shared_dir",
        property="sharedir",
        command=["dojob", "echo E:\\buildbot"]
    ));

    # that's where we will build servers
    f.addStep(SetPropertyFromCommand(
        name="set_bb_workdir",
        property="bb_workdir",
        command=["dojob", WithProperties("echo D:\\%(buildername)s")]
    ));

    # that's where the main server (server under test) will be built
    f.addStep(SetPropertyFromCommand(
        name="set_builddir",
        property="builddir",
        command=["dojob", WithProperties("echo D:\\%(buildername)s\\build")]
    ));

    # logdir is where vardirs are written
    f.addStep(SetPropertyFromCommand(
        name="set_logdir",
        property="logdir",
        command=["dojob",WithProperties("echo %(sharedir)s\\vardirs\\%(buildername)s\\%(branch)s-%(buildnumber)s")]
    ));

    f.addStep(ShellCommand(
        name= "close_open_handles",
        command=["dojob", WithProperties("cd /d %(bb_workdir)s && %(sharedir)s\\mariadb-tools\\buildbot\\unlock_handles.bat")],
        alwaysRun=True
    ));

#    f.addStep(ShellCommand(
#        name= "kill_stale_mysqld",
#        command=["dojob", WithProperties("taskkill /IM mysqld.exe /F || tasklist")],
#        locks=[kill_mysqld_lock.access('exclusive')]
#    ));

    f.addStep(ShellCommand(
        name= "kill_stale_mysqld",
	command=["dojob", WithProperties("PowerShell -Command \"Get-WmiObject -class Win32_Process | Where-Object { $_.Name -eq 'mysqld.exe' -and $_.Path -like '*\qa-win-debug\*'} | Select-Object\" && PowerShell -Command \"Get-WmiObject -class Win32_Process | Where-Object { $_.Name -eq 'mysqld.exe' -and $_.Path -like '*\qa-win-debug\*'} | Remove-WmiObject\" && PowerShell -Command \"Get-WmiObject -class Win32_Process | Where-Object { $_.Name -eq 'mysqld.exe' -and $_.Path -like '*\qa-win-debug\*'} | Select-Object\"")]
    ));

    f.addStep(RemoveDirectory(name="remove_old_builds",       dir=WithProperties("%(bb_workdir)s")));
    f.addStep(RemoveDirectory(name="remove_old_logs",    dir=WithProperties("%(logdir)s")));

    f.addStep(ShellCommand(
        name = "create_dirs",
        command=["dojob", WithProperties("mkdir %(bb_workdir)s && mkdir %(bb_workdir)s\\build-last-release")],
        timeout = 3600
    ));

    f.addStep(ShellCommand(
        name = "pull_server",
        command=["dojob", WithProperties("git clone %(sharedir)s\\mariadb-server %(builddir)s && cd /d %(builddir)s && git remote set-url origin %(repository)s && git pull && git reset --hard %(revision)s")],
        timeout = 3600
    ));

    f.addStep(ShellCommand(
        name = "pull_rqg_and_tools",
        command=["dojob", WithProperties("cd /d %(sharedir)s\\rqg && git pull && cd /d %(sharedir)s\\mariadb-toolbox && git pull")],
        locks=[git_rqg_lock.access('exclusive')],
        timeout = 3600
    ));

    f.addStep(SetPropertyFromCommand(
        name="get_generator",
        property="vs_generator",
        command=["dojob", WithProperties("cat %(sharedir)s\\vs_generator.txt")]
    ));

    f.addStep(ShellCommand(
        name = "version_info",
        command=["dojob", WithProperties("cd /d %(builddir)s && git log -1 && cd /d %(sharedir)s\\rqg && git log -1 && cd /d %(sharedir)s\\mariadb-toolbox && git log -1")],
        timeout = 3600
    ));

    f.addStep(Compile(
        name = "build",
        command=["dojob", WithProperties("cd /d %(builddir)s && cmake . -G %(vs_generator)s && cmake --build . --config "+config)],
        warningPattern=vsWarningPattern,
        warningExtractor=Compile.warnExtractFromRegexpGroups
    ));

# We shouldn't need it anymore since we are setting appverif in runall.pl now
#    f.addStep(Test(
#        name = "enable_app_verifier",
#        doStepIf=do_release_steps,
#        command=["dojob", "appverif", "/verify", "mysqld.exe"]
#    ));

    # storage tests are currently broken on 10.2 (MDEV-9705)
    f.addStep(getMTR(
        doStepIf=do_release_steps,
        name="storage_engine",
        test_type="storage_engine",
        test_info="Storage engine test suites",
        timeout=3600,
        command=["dojob", WithProperties("cd /d %(builddir)s\\mysql-test && perl mysql-test-run.pl  --verbose-restart --force --suite=storage_engine-,storage_engine/*- --max-test-fail=0 --parallel=4")]
    ));

    f.addStep(Test(
        doStepIf=do_release_steps,
        name = "transform",
        timeout=3600,
        env={"MTR_BUILD_THREAD":mtr_build_thread},
        command=["dojob", WithProperties("cd /d %(sharedir)s\\rqg && perl combinations.pl --config=%(sharedir)s\\mariadb-toolbox\\configs\\buildbot-transform.cc --run-all-combinations-once --force --basedir=%(builddir)s --workdir=%(logdir)s\\optim-transform || perl %(sharedir)s\\mariadb-toolbox\\scripts\\result_summary.pl %(logdir)s\\optim-transform\\trial*")]
    ));

# We shouldn't need it anymore since we are setting appverif in runall.pl now
#    f.addStep(ShellCommand(
#        doStepIf=do_release_steps,
#        name= "disable_app_verifier_again",
#        command=["dojob", "appverif", "/n", "mysqld.exe"]
#        alwaysRun=True
#    ));

    f.addStep(Test(
        doStepIf=do_debug_steps,
        name = "crash_tests",
        timeout=3600,
        env={"MTR_BUILD_THREAD":mtr_build_thread},
        command=["dojob", WithProperties("cd /d %(sharedir)s\\rqg && perl combinations.pl --config=%(sharedir)s\\mariadb-toolbox\\configs\\buildbot-no-comparison.cc --run-all-combinations-once --force --basedir=%(builddir)s --workdir=%(logdir)s\\optim-crash-tests || perl %(sharedir)s\\mariadb-toolbox\\scripts\\result_summary.pl %(logdir)s\\optim-crash-tests\\trial*")]
    ));

    f.addStep(ShellCommand(
        name = "get_previous_release",
        command=["dojob", WithProperties("perl %(sharedir)s\\mariadb-toolbox\\scripts\\last_release_tag.pl --source-tree=%(builddir)s --dest-tree=%(bb_workdir)s/build-last-release")],
        timeout = 3600,
        doStepIf=do_release_steps
    ));

    f.addStep(Compile(
        doStepIf=do_release_steps,
        name = "build_previous_release",
        command=["dojob", WithProperties("cd /d %(bb_workdir)s\\build-last-release && cmake . -G %(vs_generator)s && cmake --build . --config RelWithDebInfo")],
        timeout=3600,
        warningPattern=vsWarningPattern,
        warningExtractor=Compile.warnExtractFromRegexpGroups
    ));

    f.addStep(Test(
        doStepIf=do_release_steps,
        name = "comparison",
        timeout=3600,
        env={"MTR_BUILD_THREAD":mtr_build_thread},
        command=["dojob", WithProperties("cd /d %(sharedir)s\\rqg && perl combinations.pl --config=%(sharedir)s\\mariadb-toolbox\\configs\\buildbot-comparison.cc --run-all-combinations-once --force --basedir1=%(builddir)s --basedir2=%(bb_workdir)s\\build-last-release --workdir=%(logdir)s\\optim-comparison || perl %(sharedir)s\\mariadb-toolbox\\scripts\\result_summary.pl %(logdir)s\\optim-comparison\\trial*")]
    ));

#    f.addStep(Test(
#        name = "app_verifier",
#        doStepIf=False,
#        command=["dojob", WithProperties("dir %(logdir)s && appverif -export log -for mysqld.exe -with to=%(logdir)s\\appverif.xml && cat %(logdir)s\\appverif.xml")]
#    ));

    return f


bld_win_rqg_se = {
        'name': "qa-win-rel",
        'slavenames': ["bbwin3"],
        'builddir': "win-rqg-se",
#        'vsconfig': "Debug",
        'factory': rqg_win_factory(mtr_build_thread="140",config='RelWithDebInfo'),
        "nextBuild": myNextBuild,
        'category': "experimental",
#        'locks' : [release_build_lock.access('exclusive')]
}

bld_win_rqg_debug = {
        'name': "qa-win-debug",
        'slavenames': ["bbwin3"],
        'builddir': "win-rqg-debug",
#        'vsconfig': "Debug",
        'factory': rqg_win_factory(mtr_build_thread="150",config='Debug'),
        "nextBuild": myNextBuild,
        'category': "experimental",
#        'locks' : [debug_build_lock.access('exclusive')]
}

###############################################################################################
#
# Buildbot experiments

def getPackageType(step):
  if step.getProperty("buildername") == "rpm-centos7":
    return "-DRPM=centos7"
  if step.getProperty("buildername") == "rpm-centos6":
    return "-DRPM=centos6"
  if step.getProperty("buildername") == "deb-ubuntu16":
    return "-DDEB=xenial"
  if step.getProperty("buildername") == "deb-debian8":
    return "-DDEB=jessie"
  if step.getProperty("buildername") == "rpm-suse12":
    return "-DDEB=sles12"

f_bb_exp = factory.BuildFactory()

f_bb_exp.addStep(ShellCommand(command=["echo",
                                            "-DWITH_READLINE=1",
                                            getPackageType,
                                            "-DPLUGIN_CONNECT=NO"],
                                   description="ColumnStore test",
                                   descriptionDone="CS test"))

f_bb_exp.addStep(ShellCommand(
    description=["rsyncing", "VMs"],
    descriptionDone=["rsync", "VMs"],
#    doStepIf=(lambda(step): step.getProperty("slavename") != "bb01"),
    doStepIf=False,
    haltOnFailure=True,
    command=["rsync", "-a", "-v", "-L",
             "bb01.mariadb.net::kvm/vms/vm-xenial-amd64-build.qcow2",
             "bb01.mariadb.net::kvm/vms/vm-xenial-amd64-valgrind.qcow2",
             "/kvm/vms/"]))

f_bb_exp.addStep(getMTR(
#    doStepIf=isMainTree,
    doStepIf=False,
    test_info="Buildbot experiment",
    timeout=9600,
    mtr_subdir=".",
    env={"TERM": "vt102","MTR_FEEDBACK_PLUGIN": "1"},
    command=["runvm", "--base-image=/kvm/vms/vm-xenial-amd64-valgrind.qcow2", "--port=10711", "--user=buildbot", "--smp=2", "--mem=2048", "--cpu=qemu64", "--startup-timeout=600", "--logfile=kernel_10711.log", "vm-tmp-10711.qcow2",
    WithProperties("""
set -ex
wget http://hasky.askmonty.org/archive/5.5/build-12450/kvm-tarbake-jaunty-x86/mariadb-5.5.55.tar.gz
tar zxvf mariadb-5.5.55.tar.gz
cd mariadb-5.5.55
cmake . -DCMAKE_BUILD_TYPE=Debug -DWITH_VALGRIND=YES
make -j5
cd mysql-test
if perl mysql-test-run.pl  --verbose-restart --vardir="$(readlink -f /dev/shm/var)" --valgrind --valgrind-option=--show-reachable=yes --valgrind-option=--gen-suppressions=all --force --max-test-fail=100 --max-save-core=0 --max-save-datadir=1 --skip-test="tokudb\.|tokudb_alter_table\.|tokudb_bugs\.|main.mdev-504|binlog_encryption\.|rpl\." --suite=federated --parallel=2 federated.federatedx
then
  exit 0
else
  rm -rf var
  mv /dev/shm/var ./
  exit 1
fi
"""),
   WithProperties(
     "!= rm -Rf var/ ; scp -rp -P 10711 " + kvm_scpopt +
     " buildbot@localhost:~buildbot/mariadb-5.5.55/mysql-test/var . || :")
    ],
    parallel=2))

bld_qa_bb_experiments = {
        'name': "qa-buildbot-experiments",
        'slavenames': ["bb03","bb04","bb02"],
        'builddir': "qa-buildbot-experiments",
        'factory': f_bb_exp,
        "nextBuild": myNextBuild,
        'category': "experimental"
}
