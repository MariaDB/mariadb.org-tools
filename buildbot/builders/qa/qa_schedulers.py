qaTargetTrees = ["5.5", "10.0", "10.1", "10.2", "10.3", "bb-5.5-elenst*", "bb-10.0-elenst*", "bb-10.1-elenst*", "bb-10.2-elenst*", "bb-10.3-elenst*"]

def isTargetQA(step):
  return step.getProperty("branch") in qaTargetTrees

###########################
# Server tests

c['schedulers'].append(Triggerable(
        name="kvm-sched-qa-trees",
        builderNames=[
                      "qa-kvm-linux",
                      "qa-win-rel",
                      "qa-win-debug"
                     ]))

###########################
# Buildbot tests

# A scheduler for experiments with buildbot itself
c['schedulers'].append(AnyBranchScheduler(
    name="buildbot-experiments",
    treeStableTimer=60,
    change_filter=BranchFilter(on_github={"https://github.com/MariaDB/server" : ("bb-non-existing-tree")}),
    builderNames=["qa-buildbot-experiments"]
))

