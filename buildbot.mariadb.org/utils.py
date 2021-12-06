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

DEVELOPMENT_BRANCH="10.7"
RELEASABLE_BRANCHES="5.5 10.0 10.1 10.2 10.3 10.4 10.5 10.6 bb-5.5-release bb-10.0-release bb-10.1-release bb-10.2-release bb-10.3-release bb-10.4-release bb-10.5-release bb-10.6-release"
savedPackageBranches= ["5.5", "10.0", "10.1", "10.2", "10.3", "10.4", "10.5", "10.6", "10.7", "10.8", "bb-*-release", "bb-10.2-compatibility", "preview-*"]
# The trees for which we save binary packages.
releaseBranches = ["bb-*-release", "preview-10.*"]

def envFromProperties(envlist):
    d = dict()
    for e in envlist:
        d[e] = str(util.Property(e))
    d['tarbuildnum'] = str(util.Property('buildnumber'))
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
