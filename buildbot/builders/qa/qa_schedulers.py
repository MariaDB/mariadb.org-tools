qaTargetTrees_10x = ["10.0", "10.1", "10.2", "10.3", "bb-10.0-elenst*", "bb-10.1-elenst*", "bb-10.2-elenst*", "bb-10.3-elenst*", "bb-10.2-ext"]

qaTargetTrees = ["5.5", "bb-5.5-elenst*"] + qaTargetTrees_10x

qaTargetInnoDB = ["10.0", "10.1", "10.2", "10.3", "bb-10.0-marko", "bb-10.1-marko", "bb-10.2-marko", "bb-10.3-marko"]

def isTargetQA(step):
  return step.getProperty("branch") in qaTargetTrees

def isTargetQA_10x(step):
  return step.getProperty("branch") in qaTargetTrees_10x

def isTargetQA_InnoDB(step):
  return step.getProperty("branch") in qaTargetInnoDB

###########################
# Server tests

c['schedulers'].append(Triggerable(
        name="kvm-sched-qa-trees",
        builderNames=[
                      "qa-win-rel",
                      "qa-win-debug"
                     ]))

#c['schedulers'].append(Triggerable(
#        name="kvm-sched-qa-trees-10x",
#        builderNames=[
#                      "qa-kvm-linux",
#                     ]))

#c['schedulers'].append(Triggerable(
#        name="kvm-sched-qa-innodb",
#        builderNames=[
#                      "qa-innodb-upgrade",
#                     ]))


###########################
# Buildbot tests

# A scheduler for experiments with buildbot itself
#c['schedulers'].append(AnyBranchScheduler(
#    name="buildbot-experiments",
#    treeStableTimer=60,
#    change_filter=BranchFilter(on_github={"https://github.com/MariaDB/server" : ("bb-non-existing-tree")}),
#    builderNames=["qa-buildbot-experiments"]
#))
