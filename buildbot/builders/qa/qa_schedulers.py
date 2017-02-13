qaTargetTrees = ["5.5", "10.0", "10.1", "10.2", "bb-5.5-elenst", "bb-10.0-elenst", "bb-10.1-elenst", "bb-10.2-elenst", "bb-10.1-mdev-11623", "bb-10.2-mdev-11623"]

def isTargetQA(step):
  return step.getProperty("branch") in qaTargetTrees

###########################
# Buildbot tests

# A scheduler for experiments with buildbot itself
c['schedulers'].append(AnyBranchScheduler(
    name="buildbot-experiments",
    treeStableTimer=60,
#    change_filter=BranchFilter(on_github=gitBranches),
    change_filter=BranchFilter(on_github={"https://github.com/MariaDB/server" : ("bb-10.2-elenst")}),
#    change_filter=default_branch_filter,
    builderNames=["qa-buildbot-experiments"]
))

###########################
# Server tests

c['schedulers'].append(Triggerable(
        name="kvm-sched-qa-trees",
        builderNames=[
                      "kvm-qa-linux"
                     ]))

# A scheduler for RQG tests that runs Aria storage engine tests, e.g. recovery
c['schedulers'].append(AnyBranchScheduler(
    name="mariadb-rqg-mariaengine",
    change_filter=BranchFilter(on_launchpad={"lp:~maria-captains/maria/5.5" : "5.5",
                                             "lp:~maria-captains/maria/10.0" : "10.0"}),
    treeStableTimer=60,
    builderNames=["rqg-perpush-mariaengine"
                  ]))
# Replication
c['schedulers'].append(AnyBranchScheduler(
    name="mariadb-rqg-replication",
    change_filter=BranchFilter(on_launchpad={"lp:~maria-captains/maria/5.5" : "5.5",
                                             "lp:~maria-captains/maria/10.0" : "10.0"}),
    treeStableTimer=60,
    builderNames=["rqg-perpush-replication"]))

# The tests were moved to mariadb-rqg-replication,
# if it works all right, this scheduler can be removed
c['schedulers'].append(AnyBranchScheduler(
    name="mariadb-rqg-replication-checksum",
    branches=["5.2-rpl"],
    treeStableTimer=60,
    builderNames=["rqg-perpush-replication-checksum"]))

# Optimizer
# The tests were moved to win-rqg and win-rqg-se,
# if it works all right, this scheduler can be removed
c['schedulers'].append(AnyBranchScheduler(
    name="mariadb-rqg-optimizer",
    branches=["5.3-test", "5.3-test2"],
    treeStableTimer=60,
    builderNames=["rqg-perpush-optimizer"]))

# Regression tests for specific bugs
#c['schedulers'].append(AnyBranchScheduler(
#    name="rqg-bugfixes",
#    branches=["5.2", "5.3", "5.5"
#              ],
#    treeStableTimer=60,
#    builderNames=["rqg-perpush-bugfix-tests"
#                  ]))

# A scheduler for RQG and storage engine tests on a Windows machine
c['schedulers'].append(AnyBranchScheduler(
    name="windows-rqg-and-SE",
    treeStableTimer=60,
    change_filter=BranchFilter(on_launchpad={"lp:~maria-captains/maria/5.3" : "5.3",
                                             "lp:~maria-captains/maria/5.5" : "5.5",
                                             "lp:~maria-captains/maria/10.0-elenst" : "10.0-elenst",
                                             "lp:~maria-captains/maria/10.0" : "10.0"},
                               on_github={"https://github.com/MariaDB/server" : ("10.2","10.1","10.0","5.5","bb-10.2-serg")}),
    builderNames=["win-rqg-se"]
))

# execfile("/etc/buildbot/builders/qa/qa_schedulers.py");
