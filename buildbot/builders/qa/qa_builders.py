#
# Random Query Generator tests - http://www.launchpad.net/randgen
#

f_rqg_mariaengine = factory.BuildFactory()
f_rqg_mariaengine.addStep(maybe_bzr_checkout)
f_rqg_mariaengine.addStep(maybe_git_checkout)
f_rqg_mariaengine.addStep(getCompileStep(["BUILD/compile-pentium-debug-max"],
                               env={"EXTRA_FLAGS": "-O2 -Wuninitialized -DFORCE_INIT_OF_VARS",
                                    "EXTRA_CONFIGS": "--with-embedded-privilege-control",
                                    "AM_EXTRA_MAKEFLAGS": "VERBOSE=1"}))
#f_rqg_mariaengine.addStep(ShellCommand(
#        description=["patching","MTRv1"], descriptionDone=["patched","MTRv1"],
#        workdir=".",
#        command=["sh", "-c", "patch -p 0 --directory=build < mtrv1.patch || true"]))

f_rqg_mariaengine.addStep(ShellCommand(
        name = "bzr_pull_rqg",
        command=["sh", "-c", "bzr pull -d $RQG_HOME"],
        timeout = 3600
));

f_rqg_mariaengine.addStep(Test(
                command=["sh", "-c", "perl $RQG_HOME/runall.pl --mtr-build-thread=72 --basedir=. --vardir=../../vardir-maria_stress --grammar=$RQG_HOME/conf/engines/engine_stress.yy --gendata=$RQG_HOME/conf/engines/engine_stress.zz --reporter=Backtrace,ErrorLog,Recovery,Shutdown --duration=240 --queries=1M --engine=Aria --rows=10000 --mysqld=--aria-checkpoint-interval=0  --mysqld=--log-output=file --seed=time --mysqld=--safe-mode"],
                description=["RQG", "maria_stress"], name = "rqg_maria_stress"
                ))

f_rqg_mariaengine.addStep(Test(
                command=["sh", "-c", "perl $RQG_HOME/runall.pl --mtr-build-thread=72 --basedir=. --vardir=../../vardir-maria_many_indexes --grammar=$RQG_HOME/conf/engines/many_indexes.yy --gendata=$RQG_HOME/conf/engines/many_indexes.zz  --rows=10000 --reporter=Backtrace,ErrorLog,Recovery,Shutdown --duration=120 --queries=1M --engine=Aria --rows=10000 --mysqld=--aria-checkpoint-interval=0  --mysqld=--log-output=file --seed=time --mysqld=--safe-mode"],
                description=["RQG", "rqg_maria_many_indexes"], name = "rqg_maria_many_indexes"
                ))

f_rqg_mariaengine.addStep(Test(
                command=["sh", "-c", "perl $RQG_HOME/runall.pl --mtr-build-thread=72 --basedir=. --vardir=../../vardir-maria_tiny_inserts --grammar=$RQG_HOME/conf/engines/tiny_inserts.yy --gendata=$RQG_HOME/conf/engines/tiny_inserts.zz --reporter=Backtrace,ErrorLog,Recovery,Shutdown --duration=240 --queries=1M --engine=Aria --rows=10000 --mysqld=--aria-checkpoint-interval=0  --mysqld=--log-output=file --seed=time --mysqld=--safe-mode"],
                description=["RQG", "maria_tiny_inserts"], name = "rqg_maria_tiny_inserts"
                ))

f_rqg_mariaengine.addStep(Test(
                command=["sh", "-c", "perl $RQG_HOME/runall.pl --mtr-build-thread=72 --basedir=. --vardir=../../vardir-maria_varchar --grammar=$RQG_HOME/conf/engines/varchar.yy --gendata=$RQG_HOME/conf/engines/varchar.zz --reporter=Backtrace,ErrorLog,Recovery,Shutdown --duration=120 --queries=1M --engine=Aria --mysqld=--aria-checkpoint-interval=0  --mysqld=--log-output=file --seed=time --mysqld=--loose-skip-innodb --mysqld=--loose-pbxt=OFF --mysqld=--safe-mode --mysqld=--default-storage-engine=Aria"],
                description=["RQG", "maria_varchar"], name = "rqg_maria_varchar"
                ))


f_rqg_mariaengine.addStep(Test(
                command=["sh", "-c", "perl $RQG_HOME/runall.pl --mtr-build-thread=72 --basedir=. --vardir=../../vardir-maria_smf2 --grammar=$RQG_HOME/conf/smf/smf2.yy --skip-gendata --mysqld=--init-file=$RQG_HOME/conf/smf/smf2.sql --reporter=Backtrace,ErrorLog,Recovery,Shutdown --duration=120 --queries=1M --engine=Aria --mysqld=--aria-checkpoint-interval=0  --mysqld=--log-output=file --seed=time --mysqld=--loose-skip-innodb --mysqld=--loose-pbxt=OFF --mysqld=--safe-mode --mysqld=--default-storage-engine=Aria"],
                description=["RQG", "maria_smf2"], name = "rqg_maria_smf"
                ))

f_rqg_mariaengine.addStep(Test(
                command=["sh", "-c", "perl $RQG_HOME/runall.pl --mtr-build-thread=72 --basedir=. --vardir=../../vardir-maria_dbt_dml --grammar=$RQG_HOME/conf/dbt3/dbt3-dml.yy --skip-gendata --mysqld=--init-file=$RQG_HOME/conf/dbt3/dbt3-s0.0001.dump --reporter=Backtrace,ErrorLog,Recovery,Shutdown --duration=120 --queries=1M --engine=Aria --mysqld=--aria-checkpoint-interval=0  --mysqld=--log-output=file --seed=time --mysqld=--loose-skip-innodb --mysqld=--loose-pbxt=OFF --mysqld=--safe-mode --mysqld=--default-storage-engine=Aria"],
                description=["RQG", "maria_dbt_dml"], name = "rqg_maria_dbt_dml"
                ))

bld_rqg_mariaengine = {'name': 'rqg-perpush-mariaengine',
             'slavename': 'centos56-quality2',
             'builddir': 'rqg-perpush-mariaengine',
             'factory': f_rqg_mariaengine,
             "nextBuild": myNextBuild,
             'category': 'experimental',
             }

#
# Regression tests for 5.3 optimizer, to protect against diverging from 5.2 in non-subquery SELECTs
#

f_rqg_optimizer = factory.BuildFactory()
f_rqg_optimizer.addStep(maybe_bzr_checkout)
f_rqg_optimizer.addStep(maybe_git_checkout)
f_rqg_optimizer.addStep(getCompileStep(["BUILD/compile-pentium-debug-max"]))

# Fails due to bug in maria-5.2, and we would like to regression-test maria-5.3 instead
# f_rqg_optimizer.addStep(Test(
#                command=["sh", "-c", "perl $RQG_HOME/runall.pl --mtr-build-thread=73 --basedir1=. --basedir2=/home/buildbot/static/maria-5.2 --threads=1 --duration=120 --queries=1M --grammar=$RQG_HOME/conf/optimizer/range_access.yy --gendata=$RQG_HOME/conf/optimizer/range_access.zz --validator=ResultsetComparatorSimplify --engine=InnoDB --seed=time --mysqld=--sql_mode=ONLY_FULL_GROUP_BY --mysqld2=--optimizer_switch=index_merge=off --reporter=QueryTimeout,Backtrace,Shutdown"],
#                name = "rqg_optimzer_ranges1"
#                ))

f_rqg_optimizer.addStep(Test(
                command=["sh", "-c", "perl $RQG_HOME/runall.pl --mtr-build-thread=73 --basedir1=. --basedir2=/home/buildbot/static/maria-5.2 --threads=1 --duration=120 --queries=1M --grammar=$RQG_HOME/conf/optimizer/range_access2.yy --gendata=$RQG_HOME/conf/optimizer/range_access2.zz --validator=ResultsetComparatorSimplify --engine=InnoDB --seed=time --mysqld=--sql_mode=ONLY_FULL_GROUP_BY --mysqld2=--optimizer_switch=index_merge=off --reporter=QueryTimeout,Backtrace,Shutdown"],
                name = "rqg_optimzer_ranges2"
                ))

# Not stable enough for a regression test, server crashes before the end of the test 
# f_rqg_optimizer.addStep(Test(
#                command=["sh", "-c", "perl $RQG_HOME/runall.pl --mtr-build-thread=73 --basedir1=. --basedir2=/home/buildbot/static/maria-5.2 --threads=1 --duration=120 --queries=1M --grammar=$RQG_HOME/conf/optimizer/optimizer_no_subquery.yy --validator=ResultsetComparatorSimplify --engine=InnoDB --seed=time --mysqld=--sql_mode=ONLY_FULL_GROUP_BY --mysqld2=--optimizer_switch=index_merge=off --reporter=QueryTimeout,Backtrace,Shutdown"],
#                name = "rqg_optimzer_joins"
#                ))

bld_rqg_optimizer = {'name': 'rqg-perpush-optimizer',
             'slavename': 'centos56-quality2',
             'builddir': 'rqg-perpush-optimizer',
             'factory': f_rqg_optimizer,
             "nextBuild": myNextBuild,
             'category': 'experimental',
}

#
# Tests for replication enhancements
#

f_rqg_replication = factory.BuildFactory()
f_rqg_replication.addStep(maybe_bzr_checkout)
f_rqg_replication.addStep(maybe_git_checkout)
f_rqg_replication.addStep(getCompileStep(["BUILD/compile-pentium-debug-max"],
                               env={"EXTRA_FLAGS": "-O2 -Wuninitialized -DFORCE_INIT_OF_VARS",
                                    "EXTRA_CONFIGS": "--with-embedded-privilege-control",
                                    "AM_EXTRA_MAKEFLAGS": "VERBOSE=1"}))

f_rqg_replication.addStep(ShellCommand(
        name = "bzr_pull_rqg",
        command=["sh", "-c", "bzr pull -d $RQG_HOME"],
        timeout = 3600
));

# MWL#116 Efficient group commit for binary log

f_rqg_replication.addStep(Test(
                command=["sh", "-c", "perl $RQG_HOME/runall.pl --mtr-build-thread=74 --basedir=. --vardir=../../vardir-rpl_rbr_groupcommit --grammar=$RQG_HOME/conf/replication/rpl_transactions.yy --gendata=$RQG_HOME/conf/replication/rpl_transactions.zz --rpl_mode=row --threads=10 --queries=1M --duration=300 --mysqld=--sync_binlog=1 --mysqld=--innodb-flush_log_at_trx_commit=1 --mysqld=--debug_binlog_fsync_sleep=100000 --validator=None --reporter=ReplicationConsistency,Shutdown"],
		name = "rqg_rpl_rbr_groupcommit"
                ))

f_rqg_replication.addStep(Test(
                command=["sh", "-c", "perl $RQG_HOME/runall.pl --mtr-build-thread=74 --basedir=. --vardir=../../vardir-rpl_sbr_groupcommit --grammar=$RQG_HOME/conf/replication/rpl_transactions.yy --gendata=$RQG_HOME/conf/replication/rpl_transactions.zz --rpl_mode=statement --threads=10 --queries=1M --duration=300 --mysqld=--sync_binlog=1 --mysqld=--innodb-flush_log_at_trx_commit=1 --mysqld=--debug_binlog_fsync_sleep=100000 --validator=None --reporter=ReplicationConsistency,Shutdown"],
		name = "rqg_rpl_sbr_groupcommit"
                ))

# MWL#136 Cross-engine consistency for START TRANSACTION WITH CONSISTENT SNAPSHOT

f_rqg_replication.addStep(Test(
                command=["sh", "-c", "perl $RQG_HOME/runall.pl --mtr-build-thread=74 --basedir=. --vardir=../../vardir-rpl_rbr_cloneslave --grammar=$RQG_HOME/conf/replication/rpl_transactions.yy --gendata=$RQG_HOME/conf/replication/rpl_transactions.zz --rpl_mode=row --threads=10 --queries=1M --duration=300 --validator=None --mysqld=--sync_binlog=1 --mysqld=--innodb-flush_log_at_trx_commit=1 --mysqld=--debug_binlog_fsync_sleep=100000 --reporter=CloneSlave,Shutdown"],
		name = "rqg_rpl_rbr_cloneslave"
                ))

f_rqg_replication.addStep(Test(
                command=["sh", "-c", "perl $RQG_HOME/runall.pl --mtr-build-thread=74 --basedir=. --vardir=../../vardir-rpl_sbr_cloneslave --grammar=$RQG_HOME/conf/replication/rpl_transactions.yy --gendata=$RQG_HOME/conf/replication/rpl_transactions.zz --rpl_mode=statement --threads=10 --queries=1M --duration=300 --validator=None --mysqld=--sync_binlog=1 --mysqld=--innodb-flush_log_at_trx_commit=1 --mysqld=--debug_binlog_fsync_sleep=100000 --reporter=CloneSlave,Shutdown"],
		name = "rqg_rpl_sbr_cloneslave"
                ))

# Using Xtrabackup + CHANGE MASTER to provision a new slave

f_rqg_replication.addStep(Test(
                command=["sh", "-c", "perl $RQG_HOME/runall.pl --mtr-build-thread=74 --basedir=. --vardir=../../vardir-rpl_rbr_cloneslave --grammar=$RQG_HOME/conf/replication/rpl_transactions.yy --gendata=$RQG_HOME/conf/replication/rpl_transactions.zz --rpl_mode=row --threads=10 --queries=1M --duration=300 --validator=None --mysqld=--sync_binlog=1 --mysqld=--innodb-flush_log_at_trx_commit=1 --mysqld=--debug_binlog_fsync_sleep=100000 --reporter=CloneSlaveXtrabackup,Shutdown"],
		name = "rqg_rpl_rbr_xtrabackup"
                ))

f_rqg_replication.addStep(Test(
                command=["sh", "-c", "perl $RQG_HOME/runall.pl --mtr-build-thread=74 --basedir=. --vardir=../../vardir-rpl_sbr_cloneslave --grammar=$RQG_HOME/conf/replication/rpl_transactions.yy --gendata=$RQG_HOME/conf/replication/rpl_transactions.zz --rpl_mode=statement --threads=10 --queries=1M --duration=300 --validator=None --mysqld=--sync_binlog=1 --mysqld=--innodb-flush_log_at_trx_commit=1 --mysqld=--debug_binlog_fsync_sleep=100000 --reporter=CloneSlaveXtrabackup,Shutdown"],
		name = "rqg_rpl_sbr_xtrabackup"
                ))

# MWL#47 Store in binlog text of statements that caused RBR events

f_rqg_replication.addStep(Test(
                command=["sh", "-c", "perl $RQG_HOME/runall.pl --mtr-build-thread=74 --basedir=. --vardir=../../vardir-rpl_rbr_binlogtext --grammar=$RQG_HOME/conf/replication/rpl_transactions.yy --gendata=$RQG_HOME/conf/replication/rpl_transactions.zz --rpl_mode=row --threads=10 --queries=1M --duration=120 --mysqld=--debug=d,slave_crash_if_table_scan --mysqld=--binlog_annotate_row_events=1 --mysqld=--replicate_annotate_row_events=1 --validator=None --reporter=ReplicationConsistency,Shutdown"],
		name = "rqg_rpl_rbr_binlogtext"
                ))

# Row-based replication with no primary key

f_rqg_replication.addStep(Test(
                command=["sh", "-c", "perl $RQG_HOME/runall.pl --mtr-build-thread=74 --basedir=. --vardir=../../vardir-rpl_rbr_nopk --grammar=$RQG_HOME/conf/replication/rpl_transactions.yy --gendata=$RQG_HOME/conf/replication/rpl_transactions_nopk.zz --rpl_mode=row --threads=10 --queries=1M --duration=120 --validator=None --reporter=ReplicationAnalyzeTable,ReplicationConsistency,Shutdown"],
		name = "rqg_rpl_rbr_nopk"
                ))

f_rqg_replication.addStep(Test(
                command=["sh", "-c", "perl $RQG_HOME/runall.pl --mtr-build-thread=74 --basedir=. --vardir=../../vardir-rpl_rbr_checksum --grammar=$RQG_HOME/conf/replication/rpl_transactions.yy --gendata=$RQG_HOME/conf/replication/rpl_transactions.zz --rpl_mode=row --mysqld=--binlog_checksum=CRC32 --mysqld=--master-verify-checksum=1 --mysqld=--slave-sql-verify-checksum=1 --mysqld=--binlog-annotate-row-events --mysqld=--replicate-annotate-row-events --threads=10 --queries=1M --duration=300 --validator=None --reporter=ReplicationConsistency,Shutdown"],
		name = "rqg_rpl_rbr_checksum"
                ))

bld_rqg_replication = {'name': 'rqg-perpush-replication',
             'slavename': 'centos56-quality2',
             'builddir': 'rqg-perpush-replication',
             'factory': f_rqg_replication,
             "nextBuild": myNextBuild,
             'category': 'experimental',
             }

# WL #180 Binlog event checksums

f_rqg_replication_checksum = factory.BuildFactory()
f_rqg_replication_checksum.addStep(maybe_bzr_checkout)
f_rqg_replication_checksum.addStep(maybe_git_checkout)
f_rqg_replication_checksum.addStep(getCompileStep(["BUILD/compile-pentium64-debug-max"],
                               env={"EXTRA_FLAGS": "-DFORCE_INIT_OF_VARS",
                                    "AM_EXTRA_MAKEFLAGS": "VERBOSE=1"}))

f_rqg_replication_checksum.addStep(Test(
                command=["sh", "-c", "perl $RQG_HOME/runall.pl --mtr-build-thread=75 --basedir=. --vardir=../../vardir-rpl_rbr_checksum --grammar=$RQG_HOME/conf/replication/rpl_transactions.yy --gendata=$RQG_HOME/conf/replication/rpl_transactions.zz --rpl_mode=row --mysqld=--binlog_checksum=CRC32 --mysqld=--master-verify-checksum=1 --mysqld=--slave-sql-verify-checksum=1 --mysqld=--binlog-annotate-row-events --mysqld=--replicate-annotate-row-events --threads=10 --queries=1M --duration=300 --validator=None --reporter=ReplicationConsistency,Shutdown"],
		name = "rqg_rpl_rbr_checksum"
                ))

bld_rqg_replication_checksum = {'name': 'rqg-perpush-replication-checksum',
             'slavename': 'centos56-quality2',
             'builddir': 'rqg-perpush-replication-checksum',
             'factory': f_rqg_replication_checksum,
             "nextBuild": myNextBuild,
             'category': 'experimental',
             }


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
             "bb01.mariadb.net::kvm/vms/vm-jessie-amd64-qa.qcow2",
             "bb01.mariadb.net::kvm/vms/vm-jessie-amd64-qa-upgrade.qcow2",
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
    command=["runvm", "--base-image=/kvm/vms/vm-jessie-amd64-qa-upgrade.qcow2", "--port=10710", "--user=buildbot", "--smp=4", "--cpu=qemu64", "--startup-timeout=600", "--logfile=kernel_10710.log", "vm-tmp-build-10710.qcow2",
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
#    doStepIf=(lambda(step): branch_is_10_x(step) and branch_is_not_10_3(step)),
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
#    doStepIf=(lambda(step): branch_is_10_2_or_later(step) and branch_is_not_10_3(step)),
    doStepIf=(lambda(step): step.getProperty("branch") == "bb-10.1-mdev-11623" or step.getProperty("branch") == "bb-10.2-mdev-11623" or step.getProperty("branch") == "10.1" or step.getProperty("branch") == "10.2" or step.getProperty("branch") == "bb-10.2-elenst"),
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
*10.0*|*10.1*)
  config=bb-upgrade-from-10.0-small.cc
  ;;
*)
  config=bb-upgrade-10.0-to-10.2-small.cc
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
#    doStepIf=(lambda(step): branch_is_10_2_or_later(step) and branch_is_not_10_3(step)),
    doStepIf=(lambda(step): step.getProperty("branch") == "bb-10.1-mdev-11623" or step.getProperty("branch") == "bb-10.2-mdev-11623" or step.getProperty("branch") == "10.1" or step.getProperty("branch") == "10.2" or step.getProperty("branch") == "bb-10.2-elenst"),
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
if perl ./combinations.pl --new --config=/home/buildbot/mariadb-toolbox/configs/bb-upgrade-from-mysql-5.6-small.cc --run-all-combinations-once --force --workdir=/home/buildbot/upgrade-from-mysql-5.6
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
#    doStepIf=(lambda(step): branch_is_10_2_or_later(step) and branch_is_not_10_3(step)),
    doStepIf=(lambda(step): step.getProperty("branch") == "bb-10.1-mdev-11623" or step.getProperty("branch") == "bb-10.2-mdev-11623" or step.getProperty("branch") == "10.1" or step.getProperty("branch") == "10.2" or step.getProperty("branch") == "bb-10.2-elenst"),
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
  config=bb-upgrade-from-10.1-small.cc
  ;;
*)
  config=bb-upgrade-10.1-to-10.2-small.cc
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
#    doStepIf=(lambda(step): branch_is_10_2_or_later(step) and branch_is_not_10_3(step)),
#    doStepIf=(lambda(step): step.getProperty("branch") == "bb-10.2-mdev-11623" or step.getProperty("branch") == "10.2"),
    doStepIf=False,
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
#    doStepIf=(lambda(step): branch_is_10_2_or_later(step) and branch_is_not_10_3(step)),
#    doStepIf=False,
    doStepIf=(lambda(step): step.getProperty("branch") == "10.2"),
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
#    doStepIf=(lambda(step): branch_is_10_x(step) and branch_is_not_10_3(step)),
#    doStepIf=False,
    doStepIf=(lambda(step): step.getProperty("branch") == "10.0" or step.getProperty("branch") == "10.1"),
    name="engines",
    test_type="engines",
    test_info="MySQL engines/* tests",
    timeout=7200,
    env={"TERM": "vt102"},
    command=["runvm", "--base-image=vm-tmp-build-10710.qcow2", "--port=10710", "--user=buildbot", "--smp=4", "--cpu=qemu64", "--startup-timeout=600", "--logfile=kernel_10710.log", "vm-tmp-10710.qcow2",
    WithProperties("""
set -ex
cd build/mysql-test
perl mysql-test-run.pl  --verbose-restart --force --max-save-core=0 --max-save-datadir=1 --suite=engines/funcs,engines/iuds --parallel=4 --mysqld=--open-files-limit=0 --mem --verbose-restart
"""),
    ]))

f_qa_linux.addStep(getMTR(
#    doStepIf=(lambda(step): branch_is_10_x(step) and branch_is_not_10_3(step) and branch_is_not_10_2(step)),
    doStepIf=False,
#    doStepIf=(lambda(step): step.getProperty("branch") == "10.1"),
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
        'name': "kvm-qa-linux",
        'slavenames': ["bb02","bb03","bb04"],
        'builddir': "kvm-qa-linux",
        'factory': f_qa_linux,
        "nextBuild": myNextBuild,
        'category': "experimental"
}

###############################################################################################
#
# RQG and storage engine tests on a Windows machine (light for 5.3, extended for 5.5 and 10.x)


f_win_rqg_se = factory.BuildFactory()

from buildbot.steps.slave import RemoveDirectory

f_win_rqg_se.addStep(ShellCommand(
        name= "disable_app_verifier",
        command=["dojob", "appverif", "/n", "mysqld.exe"],
        alwaysRun=True
));

# script_dir is where rqg, mariadb-toolbox etc. are,
# e.g. E:\buildbot
f_win_rqg_se.addStep(SetPropertyFromCommand(
        property="scriptdir",
        command=["dojob", "echo %cd%\\..\\..\\.."]
));

# bbdir is the home dir for the builder, it's where sources and builds are, 
# e.g. E:\buildbot\bbwin1\win-rqg-se
f_win_rqg_se.addStep(SetPropertyFromCommand(
        property="bbdir",
        command=["dojob", "echo %cd%\\.."]
));

# logdir is where vardirs are written, e.g.
# E:\buildbot\vardirs\<name>
f_win_rqg_se.addStep(SetPropertyFromCommand(
        property="logdir",
        command=["dojob",WithProperties("echo %(scriptdir)s\\vardirs\\%(branch)s-%(buildnumber)s")]
));


f_win_rqg_se.addStep(SetPropertyFromCommand(
        property="vs_generator",
        command=["dojob", WithProperties("cat %(scriptdir)s\\vs_generator.txt")]
));

f_win_rqg_se.addStep(RemoveDirectory(name="remove_build",       dir=WithProperties("%(bbdir)s\\build")));
f_win_rqg_se.addStep(RemoveDirectory(name="remove_debug_build", dir=WithProperties("%(bbdir)s\\build-debug")));
f_win_rqg_se.addStep(RemoveDirectory(name="remove_last_release",dir=WithProperties("%(bbdir)s\\build-last-release")));
f_win_rqg_se.addStep(RemoveDirectory(name="remove_old_logs",    dir=WithProperties("%(logdir)s")));

# Clones the required revision into c:\buildbot\<slave name>\<builder name>\build
f_win_rqg_se.addStep(maybe_bzr_checkout)
f_win_rqg_se.addStep(maybe_git_checkout)

#f_win_rqg_se.addStep(ShellCommand(
#        name = "bzr_checkout_debug",
#        command=["dojob", "bzr" ,"checkout", "-r", WithProperties("%(revision)s"), WithProperties("lp:~maria-captains/maria/%(branch)s"), WithProperties("c:\\buildbot\\%(buildername)s\\build-debug")],
#	doStepIf=not_on_github,
#        timeout = 4*3600
#));

# Copies  c:\buildbot\<slave name>\<builder name>\build into  c:\buildbot\<slave name>\<builder name>\build-debug
f_win_rqg_se.addStep(ShellCommand(
        name = "copy_for_debug",
        command=["dojob", "cp", "-r", WithProperties("%(bbdir)s\\build"), WithProperties("%(bbdir)s\\build-debug")],
        timeout = 3600
));

#f_win_rqg_se.addStep(ShellCommand(
#        name = "bzr_checkout_non_debug",
#        command=["dojob", "bzr" ,"checkout", WithProperties("c:\\buildbot\\%(buildername)s\\build-debug"), WithProperties("c:\\buildbot\\%(buildername)s\\build")],
#	doStepIf=branch_is_5_5_or_later and not_on_github,
#        timeout = 4*3600
#));

f_win_rqg_se.addStep(ShellCommand(
        name = "pull_rqg",
        command=["dojob", WithProperties("cd %(scriptdir)s\\rqg && git pull && cd %(scriptdir)s\\mariadb-toolbox && git pull")],
        timeout = 3600
));

f_win_rqg_se.addStep(ShellCommand(
        name = "get_previous_release",
        command=["dojob", WithProperties("perl %(scriptdir)s\\mariadb-toolbox\\scripts\\last_release_tag.pl --source-tree=%(bbdir)s/build-debug --dest-tree=%(bbdir)s/build-last-release")],
        timeout = 3600
));

f_win_rqg_se.addStep(ShellCommand(
        name = "bzr_version_info",
        command=["dojob", WithProperties("bzr version-info %(bbdir)s\\build-debug && bzr version-info %(bbdir)s\\build-last-release && bzr version-info %(bbdir)s\\..\\..\\rqg && cd %(scriptdir)s\\mariadb-toolbox && git log -1")],
        doStepIf=not_on_github
));

f_win_rqg_se.addStep(ShellCommand(
        name = "version_info",
        command=["dojob", WithProperties("cd %(bbdir)s\\build-debug && git log -1 && cd %(bbdir)s\\build-last-release && git log -1 && bzr version-info %(scriptdir)s\\rqg && cd %(scriptdir)s\\mariadb-toolbox && git log -1")],
        timeout = 3600,
        doStepIf=on_github
));

f_win_rqg_se.addStep(Compile(
        name = "build_debug",
        command=["dojob", WithProperties("cd %(bbdir)s\\build-debug && cmake . -G %(vs_generator)s && cmake --build . --config Debug")],
        warningPattern=vsWarningPattern,
        warningExtractor=Compile.warnExtractFromRegexpGroups
));

# storage tests are currently broken on 10.2 (MDEV-9705)
f_win_rqg_se.addStep(getMTR(
	doStepIf=branch_is_not_10_2,
        test_type="storage_engine", 
        test_info="Storage engine test suites",
	timeout=3600,
        command=["dojob", WithProperties("cd %(bbdir)s\\build-debug\mysql-test && perl mysql-test-run.pl  --verbose-restart --force --suite=storage_engine-,storage_engine/*- --max-test-fail=0 --parallel=4")]
));

#f_win_rqg_se.addStep(Test(
#        doStepIf=False, #####
#        name = "rqg_opt_subquery_myisam",
#        command=["dojob", WithProperties("cd %(scriptdir)s\\rqg && perl runall.pl --queries=100M --seed=time --threads=4 --duration=300 --reporters=QueryTimeout,Backtrace,ErrorLog,Deadlock,Shutdown --mysqld=--log-output=FILE --grammar=%(scriptdir)s\\mariadb-toolbox\\grammars\\optimizer_subquery_simple.yy --views --engine=MyISAM --basedir=%(bbdir)s\\build-debug --vardir=%(logdir)s\\optim_sq_myisam")]
#));

f_win_rqg_se.addStep(Test(
        name = "rqg_crash_tests",
	timeout=3600,
        command=["dojob", WithProperties("cd %(scriptdir)s\\rqg && perl combinations.pl --config=%(scriptdir)s\\mariadb-toolbox\\configs\\buildbot-no-comparison.cc --run-all-combinations-once --force --basedir=%(bbdir)s\\build-debug --workdir=%(logdir)s\\optim-crash-tests"), '||', "perl", WithProperties("%(scriptdir)s\\mariadb-toolbox\\scripts\\result_summary.pl"), WithProperties("%(logdir)s\\optim-crash-tests\\trial*")]
));

#f_win_rqg_se.addStep(Test(
#        name = "rqg_bugfix_tests",
#	doStepIf=False,
#        command=["dojob", WithProperties("cd %(scriptdir)s\\rqg && perl combinations.pl --config=%(scriptdir)s\\mariadb-toolbox\\configs\\buildbot_regression_tests.cc --run-all-combinations-once --force --basedir=%(bbdir)s\\build-debug --workdir=%(logdir)s\\bugfix_tests")]
#));

f_win_rqg_se.addStep(Compile(
        name = "build_relwithdebinfo",
        doStepIf=branch_is_5_5_or_later,
	timeout=3600,
        command=["dojob", WithProperties("cd %(bbdir)s\\build && cmake . -G %(vs_generator)s && cmake --build . --config RelWithDebInfo")],
	warningPattern=vsWarningPattern,
        warningExtractor=Compile.warnExtractFromRegexpGroups
));

f_win_rqg_se.addStep(Compile(
        name = "build_previous_release",
        command=["dojob", WithProperties("cd %(bbdir)s\\build-last-release && cmake . -G %(vs_generator)s && cmake --build . --config RelWithDebInfo")],
	timeout=3600,
        warningPattern=vsWarningPattern,
        warningExtractor=Compile.warnExtractFromRegexpGroups
));

# Again problems with appverifier,
# now the tests just report crashes, but no stack trace or anything in the log
f_win_rqg_se.addStep(Test(
        name = "enable_app_verifier",
#        doStepIf=branch_is_10_1_or_later,
	doStepIf=False,
        command=["dojob", "appverif", "/verify", "mysqld.exe"]
));

f_win_rqg_se.addStep(Test(
        name = "rqg_opt_comparison",
	timeout=3600,
        command=["dojob", WithProperties("cd %(scriptdir)s\\rqg && perl combinations.pl --config=%(scriptdir)s\\mariadb-toolbox\\configs\\buildbot-comparison.cc --run-all-combinations-once --force --basedir1=%(bbdir)s\\build --basedir2=%(bbdir)s\\build-last-release --workdir=%(logdir)s\\optim-comparison"), '||', "perl", WithProperties("%(scriptdir)s\\mariadb-toolbox\\scripts\\result_summary.pl"), WithProperties("%(logdir)s\\optim-comparison\\trial*")]
));

#f_win_rqg_se.addStep(Test(
#        name = "rqg_engine_stress_innodb",
##        doStepIf=branch_is_5_5_or_later,
#	doStepIf=False,
#        command=["dojob", WithProperties("cd %(scriptdir)s\\rqg && perl runall.pl --queries=100M --seed=time --threads=16 --duration=600 --reporters=QueryTimeout,Backtrace,ErrorLog,Deadlock,Shutdown --mysqld=--log-output=FILE --grammar=conf/engines/engine_stress.yy --gendata=conf/engines/engine_stress.zz --engine=InnoDB --basedir=%(bbdir)s\\build --vardir=%(logdir)s\\engine_stress_innodb && appverif /n mysqld.exe")]
#));

#f_win_rqg_se.addStep(Test(
#        name = "rqg_opt_ranges2",
#	timeout=3600,
#        command=["dojob", WithProperties("cd %(scriptdir)s\\rqg && perl runall.pl --basedir1=%(bbdir)s\\build-debug --basedir2=%(scriptdir)s\\5.2.14 --threads=1 --duration=120 --queries=1M --grammar=conf/optimizer/range_access2.yy --gendata=conf/optimizer/range_access2.zz --validator=ResultsetComparatorSimplify --engine=InnoDB --seed=time --mysqld=--sql_mode=ONLY_FULL_GROUP_BY --mysqld2=--optimizer_switch=index_merge=off --reporter=QueryTimeout,Backtrace,Shutdown --vardir1=%(logdir)s\\ranges2-%(branch)s --vardir2=%(logdir)s\\ranges2-5.2")]
#));

f_win_rqg_se.addStep(ShellCommand(
        name= "disable_app_verifier_again",
        command=["dojob", "appverif", "/n", "mysqld.exe"],
        alwaysRun=True
));

# The tests are very slow on the current Windows builder, and fail with a timeout often. 
# In attempt to get rid of the timeouts, run them without appverif, 
# add innodb-flush-log-at-trx-commit=0 and increase the timeout
#f_win_rqg_se.addStep(getMTR(
##	doStepIf=branch_is_10_x,
#        doStepIf=False, #####
#        test_type="engines", 
#        test_info="engines/* test suites",
#        command=["dojob", WithProperties("cd %(bbdir)s\\build\mysql-test && perl mysql-test-run.pl  --verbose-restart --force --suite=engines/funcs,engines/iuds --parallel=4 --mysqld=--loose-innodb-flush-log-at-trx-commit=0 --testcase-timeout=60")]
#));

# Disabled due to MDEV-10010
f_win_rqg_se.addStep(Test(
        name = "app_verifier",
#        doStepIf=branch_is_5_5_or_later,
	doStepIf=False,
        command=["dojob", WithProperties("appverif -export log -for mysqld.exe -with to=%(logdir)s\\engine_stress_innodb\\appverif.xml && cat %(logdir)s\\engine_stress_innodb\\appverif.xml")]
))

bld_win_rqg_se = {
        'name': "win-rqg-se",
        'slavenames': ["bbwin3"],
        'builddir': "win-rqg-se",
#        'vsconfig': "Debug",
        'factory': f_win_rqg_se,
        "nextBuild": myNextBuild,
        'category': "experimental"
}

###############################################################################################
#
# Buildbot experiments

f_bb_exp = factory.BuildFactory()

f_bb_exp.addStep(ShellCommand(
    description=["rsyncing", "VMs"],
    descriptionDone=["rsync", "VMs"],
    doStepIf=(lambda(step): step.getProperty("slavename") != "bb01"),
    haltOnFailure=True,
    command=["rsync", "-a", "-v", "-L",
             "bb01.mariadb.net::kvm/vms/vm-xenial-amd64-build.qcow2",
             "bb01.mariadb.net::kvm/vms/vm-xenial-amd64-valgrind.qcow2",
             "/kvm/vms/"]))

f_bb_exp.addStep(getMTR(
#    doStepIf=isMainTree,
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
