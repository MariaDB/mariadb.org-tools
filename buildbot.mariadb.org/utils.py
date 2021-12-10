from buildbot.plugins import *
from buildbot.process.properties import Property, Properties
from buildbot.steps.shell import ShellCommand, Compile, Test, SetPropertyFromCommand
from buildbot.steps.mtrlogobserver import MTR, MtrLogObserver
from buildbot.steps.source.github import GitHub
from buildbot.process.remotecommand import RemoteCommand
from twisted.internet import defer
import sys
import docker
from datetime import timedelta

from constants import *

DEVELOPMENT_BRANCH="10.7"
RELEASABLE_BRANCHES="5.5 10.0 10.1 10.2 10.3 10.4 10.5 10.6 bb-5.5-release bb-10.0-release bb-10.1-release bb-10.2-release bb-10.3-release bb-10.4-release bb-10.5-release bb-10.6-release"
savedPackageBranches= ["5.5", "10.0", "10.1", "10.2", "10.3", "10.4", "10.5", "10.6", "10.7", "10.8", "bb-*-release", "bb-10.2-compatibility", "preview-*"]
# The trees for which we save binary packages.
releaseBranches = ["bb-*-release", "preview-10.*"]

def envFromProperties(envlist):
    d = dict()
    for e in envlist:
        d[e] = util.Interpolate(f'%(prop:{e})s')
    d['tarbuildnum'] = util.Interpolate("%(prop:buildnumber)s")
    d['releaseable_branches'] = RELEASABLE_BRANCHES
    d['development_branch']= DEVELOPMENT_BRANCH
    return d

def getScript(scriptname):
    return steps.ShellCommand(
      name=f"fetch_{scriptname}",
      command=['sh', '-xc', f"curl https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot.mariadb.org/scripts/{scriptname} -o {scriptname} && chmod a+x {scriptname}"])

# BUILD HELPERS

# git branch filter using fnmatch
import fnmatch
def staging_branch_fn(branch):
    return fnmatch.fnmatch(branch, 'prot-st-*')
def fnmatch_any(s, list_of_patterns):
    return any(fnmatch.fnmatch(s, p) for p in list_of_patterns)

# Priority filter based on saved package branches
def nextBuild(bldr, requests):
    for r in requests:
        if fnmatch_any(r.sources[""].branch, releaseBranches):
            return r
    for r in requests:
        if fnmatch_any(r.sources[""].branch, savedPackageBranches):
            return r
    return requests[0]

@defer.inlineCallbacks
def shell(command, worker, builder):
    args = {
        'command': command,
        'logEnviron': False,
        'workdir': "/srv/buildbot/worker",
        'want_stdout': False,
        'want_stderr': False,
    }
    cmd = RemoteCommand('shell', args, stdioLogName=None)
    cmd.worker = worker
    yield cmd.run(FakeStep(), worker.conn, builder.name)
    return cmd.rc

@defer.inlineCallbacks
def canStartBuild(builder, wfb, request):
    worker=wfb.worker
    return True
    # check worker load over the last 5 minutes
    rc = yield shell(
        'test "$(cut -d" " -f2 /proc/loadavg | cut -d. -f1)" -le "$(( $(nproc) / 2 ))"',
        worker, builder)
    if rc != 0:
        log.msg('loadavg is too high to take new builds',
                system=repr(worker))
        worker.putInQuarantine()
        return False

    worker.quarantine_timeout = 180
    worker.putInQuarantine()
    worker.resetQuarantine()
    return True

@util.renderer
def mtrJobsMultiplier(props):
    jobs = props.getProperty('jobs', default=20)
    return jobs * 2

# ls2string gets the output of ls and returns a space delimited string with the files and directories
def ls2string(rc, stdout, stderr):
    lsFilenames = []

    for l in stdout.strip().split('\n'):
        if l != "":
            lsFilenames.append(l.strip())

    return { 'packages' : " ".join(lsFilenames) }

# ls2list gets the output of ls and returns a list with the files and directories
def ls2list(rc, stdout, stderr):
    lsFilenames = []

    for l in stdout.strip().split('\n'):
        if l != "":
            lsFilenames.append(l.strip())

    return { 'packages' : lsFilenames }

# Save packages for current branch?
def savePackage(step):
    return step.getProperty("save_packages") and \
           (fnmatch_any(step.getProperty("branch"), savedPackageBranches) or \
           str(step.getProperty("buildername")).endswith('ubuntu-2004-deb-autobake'))

# Return a HTML file that contains links to MTR logs
def getHTMLLogString():
    return """
echo '<!DOCTYPE html>
<html>
<body>' >> /buildbot/mysql_logs.html

echo '<a href="https://ci.mariadb.org/%(prop:tarbuildnum)s/logs/%(prop:buildername)s/">mysqld* log dir</a><br>' >> /buildbot/mysql_logs.html

echo '</body>
</html>' >> /buildbot/mysql_logs.html"""

# Function to move the MTR logs to a known location so that they can be saved
def moveMTRLogs():
    return """
parallel=$(expr %(kw:jobs)s \* 2)

mkdir -p /buildbot/logs
for ((mtr=0; mtr<=parallel; mtr++)); do
    for mysqld in {1..4}; do
        if [ $mtr = 0 ]; then
            logname="mysqld."$mysqld".err"
            filename="mysql-test/var/log/mysqld."$mysqld".err"
        else
            logname="mysqld."$mysqld".err."$mtr
            filename="mysql-test/var/"$mtr"/log/mysqld."$mysqld".err"
        fi
        if [ -e $filename ]; then
            cp $filename /buildbot/logs/$logname
        fi
    done
done
"""

@util.renderer
def dockerfile(props):
    worker = props.getProperty('workername')
    return "https://github.com/MariaDB/mariadb.org-tools/tree/master/buildbot.mariadb.org/dockerfiles/" + "-".join(worker.split('-')[-2:]) + '.dockerfile'

# checks if the list of files is empty
def hasFiles(step):
  if len(step.getProperty("packages")) < 1:
    return False
  else:
    return True

def hasInstall(props):
    builderName = str(props.getProperty("buildername"))

    for b in builders_install:
        if builderName in b:
            return True
    return False

def hasUpgrade(props):
    builderName = str(props.getProperty("buildername"))

    for b in builders_upgrade:
        if builderName in b:
            return True
    return False

def hasEco(props):
    builderName = str(props.getProperty("buildername"))

    for b in builders_eco:
        if builderName in b:
            return True
    return False

@util.renderer
def getDockerLibraryNames(props):
    return builders_dockerlibrary[0]

def hasDockerLibrary(props):
    branch = str(props.getProperty("master_branch"))
    builderName = str(props.getProperty("buildername"))

    # from https://github.com/MariaDB/mariadb-docker/blob/master/update.sh#L4-L7
    if branch == "10.2":
        dockerbase = "ubuntu-1804-deb-autobake"
    else:
        dockerbase = "ubuntu-2004-deb-autobake"

    # We only build on the above two autobakes for all architectures
    return builderName.endswith(dockerbase)

def filterBranch(step):
  if '10.5' in step.getProperty("branch"):
        return False
  if '10.6' in step.getProperty("branch"):
        return False
  return True

# check if branch is a staging branch
def isStagingBranch(step):
  if staging_branch_fn(step.getProperty("branch")):
    return True
  else:
    return False

# returns true if build is succeeding
def ifStagingSucceeding(step):
  if isStagingBranch(step):
    step.setProperty("build_results", step.build.results)
    return step.build.results in ('SUCCESS', 'WARNINGS')
  else:
    return False

# set step's waitForFinish to True if staging branch
def waitIfStaging(step):
  if isStagingBranch(step):
    step.waitForFinish = True
  return True

def hasAutobake(props):
    builderName = props.getProperty("buildername")
    for b in builders_autobake:
        if builderName in b:
            return True
    return False

def hasBigtest(props):
    builderName = str(props.getProperty("buildername"))

    for b in builders_big:
        if builderName in b:
            return True
    return False

@util.renderer
def getArch(props):
    buildername = props.getProperty('buildername')
    return buildername.split('-')[0]

####### SCHEDULER HELPER FUNCTIONS
@util.renderer
def getBranchBuilderNames(props):
    mBranch = props.getProperty("master_branch")

    return supportedPlatforms[mBranch]

@util.renderer
def getAutobakeBuilderNames(props):
    builderName = props.getProperty("parentbuildername")
    for b in builders_autobake:
        if builderName in b:
            return [b]
    return []

@util.renderer
def getBigtestBuilderNames(props):
    builderName = str(props.getProperty("parentbuildername"))

    for b in builders_big:
        if builderName in b:
            return [b]
    return []

@util.renderer
def getInstallBuilderNames(props):
    builderName = str(props.getProperty("parentbuildername"))

    for b in builders_install:
        if builderName in b:
            return [b]
    return []

@util.renderer
def getUpgradeBuilderNames(props):
    builderName = str(props.getProperty("parentbuildername"))

    builds = []
    for b in builders_upgrade:
        if builderName in b:
            builds.append(b)
    return builds

@util.renderer
def getEcoBuilderNames(props):
    builderName = str(props.getProperty("parentbuildername"))

    builds = []
    for b in builders_eco:
        if builderName in b:
            builds.append(b)
    return builds

