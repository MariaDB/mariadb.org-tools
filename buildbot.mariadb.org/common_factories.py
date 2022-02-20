from buildbot.plugins import *
from buildbot.process.properties import Property, Properties
from buildbot.steps.shell import ShellCommand, Compile, Test, SetPropertyFromCommand
from buildbot.steps.mtrlogobserver import MTR, MtrLogObserver
from buildbot.steps.source.github import GitHub
from buildbot.process.remotecommand import RemoteCommand
from twisted.internet import defer

from utils import *
from constants import *

def downloadSourceTarball():
    return ShellCommand(
             name="fetch_tarball",
             description="fetching source tarball",
             descriptionDone="fetching source tarball...done",
             haltOnFailure=True,
             command=["bash", "-xc", util.Interpolate("""
  d=/mnt/packages/
  f="%(prop:tarbuildnum)s_%(prop:mariadb_version)s.tar.gz"
  find $d -type f -mtime +2 -delete -ls
  for i in `seq 1 10`;
  do
    if flock "$d$f" wget -cO "$d$f" "https://ci.mariadb.org/%(prop:tarbuildnum)s/%(prop:mariadb_version)s.tar.gz"; then
        break
    else
        sleep $i
    fi
  done
""")])

def getQuickBuildFactory(mtrDbPool):
    f_quick_build = util.BuildFactory()
    f_quick_build.addStep(steps.SetProperty(property="dockerfile", value=util.Interpolate("%(kw:url)s", url=dockerfile), description="dockerfile"))
    f_quick_build.addStep(downloadSourceTarball())
    f_quick_build.addStep(steps.ShellCommand(command=util.Interpolate("tar -xvzf /mnt/packages/%(prop:tarbuildnum)s_%(prop:mariadb_version)s.tar.gz --strip-components=1")))
    f_quick_build.addStep(steps.ShellCommand(name="create html log file", command=['bash', '-c', util.Interpolate(getHTMLLogString(), jobs=util.Property('jobs', default='$(getconf _NPROCESSORS_ONLN)'))]))
    # build steps
    f_quick_build.addStep(steps.Compile(command=
        ["sh", "-c", util.Interpolate("export PATH=/usr/lib/ccache:/usr/lib64/ccache:$PATH && cmake . -DCMAKE_BUILD_TYPE=%(kw:build_type)s -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_C_COMPILER=%(kw:c_compiler)s -DCMAKE_CXX_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER=%(kw:cxx_compiler)s -DPLUGIN_TOKUDB=NO -DPLUGIN_MROONGA=NO -DPLUGIN_SPIDER=NO -DPLUGIN_OQGRAPH=NO -DPLUGIN_PERFSCHEMA=%(kw:perf_schema)s -DPLUGIN_SPHINX=NO %(kw:additional_args)s && make -j%(kw:jobs)s package", perf_schema=util.Property('perf_schema', default='YES'), build_type=util.Property('build_type', default='RelWithDebInfo'), jobs=util.Property('jobs', default='$(getconf _NPROCESSORS_ONLN)'), c_compiler=util.Property('c_compiler', default='gcc'), cxx_compiler=util.Property('cxx_compiler', default='g++'), additional_args=util.Property('additional_args', default='') )], env={'CCACHE_DIR':'/mnt/ccache'}, haltOnFailure="true"))

    f_quick_build.addStep(steps.MTR(logfiles={"mysqld*": "/buildbot/mysql_logs.html"}, command=
        ["sh", "-c", util.Interpolate("cd mysql-test && exec perl mysql-test-run.pl --verbose-restart --force --retry=3 --max-save-core=1 --max-save-datadir=1 --max-test-fail=20 --mem --parallel=$(expr %(kw:jobs)s \* 2) %(kw:mtr_additional_args)s", mtr_additional_args=util.Property('mtr_additional_args', default=''), jobs=util.Property('jobs', default='$(getconf _NPROCESSORS_ONLN)'))], timeout=7200, haltOnFailure="true", parallel=mtrJobsMultiplier, dbpool=mtrDbPool, autoCreateTables=True))
    f_quick_build.addStep(steps.ShellCommand(name="move mysqld log files", alwaysRun=True, command=['bash', '-c', util.Interpolate(moveMTRLogs(), jobs=util.Property('jobs', default='$(getconf _NPROCESSORS_ONLN)'))]))
    f_quick_build.addStep(steps.DirectoryUpload(name="save mysqld log files", compress="bz2", alwaysRun=True,  workersrc='/buildbot/logs/', masterdest=util.Interpolate('/srv/buildbot/packages/' + '%(prop:tarbuildnum)s' + '/logs/' + '%(prop:buildername)s' )))
    ## trigger packages
    f_quick_build.addStep(steps.Trigger(schedulerNames=['s_packages'], waitForFinish=False, updateSourceStamp=False, alwaysRun=True,
        set_properties={"parentbuildername": Property('buildername'), "tarbuildnum" : Property("tarbuildnum"), "mariadb_version" : Property("mariadb_version"), "master_branch" : Property("master_branch")}, doStepIf=hasAutobake))
    ## trigger bigtest
    f_quick_build.addStep(steps.Trigger(schedulerNames=['s_bigtest'], waitForFinish=False, updateSourceStamp=False,
        set_properties={"parentbuildername": Property('buildername'), "tarbuildnum" : Property("tarbuildnum"), "mariadb_version" : Property("mariadb_version"), "master_branch" : Property("master_branch")}, doStepIf=hasBigtest))
    # create package and upload to master
    f_quick_build.addStep(steps.SetPropertyFromCommand(command="basename mariadb-*-linux-*.tar.gz", property="mariadb_binary", doStepIf=savePackage))
    f_quick_build.addStep(steps.ShellCommand(name='save_packages', timeout=7200, haltOnFailure=True, command=util.Interpolate('mkdir -p ' + '/packages/' + '%(prop:tarbuildnum)s' + '/' + '%(prop:buildername)s'+ ' && sha256sum %(prop:mariadb_binary)s >> sha256sums.txt  && cp ' + '%(prop:mariadb_binary)s sha256sums.txt' + ' /packages/' + '%(prop:tarbuildnum)s' + '/' + '%(prop:buildername)s' + '/' +  ' && sync /packages/' + '%(prop:tarbuildnum)s'), doStepIf=savePackage))
    f_quick_build.addStep(steps.Trigger(name='eco', schedulerNames=['s_eco'], waitForFinish=False, updateSourceStamp=False, set_properties={"parentbuildername": Property("buildername"), "tarbuildnum" : Property("tarbuildnum"), "mariadb_binary": Property("mariadb_binary"), "mariadb_version" : Property("mariadb_version"), "master_branch" : Property("master_branch"), "parentbuildername": Property("buildername")}, doStepIf=lambda step: savePackage(step) and hasEco(step)))
    f_quick_build.addStep(steps.ShellCommand(name="cleanup", command="rm -r * .* 2> /dev/null || true", alwaysRun=True))
    return f_quick_build

def getRpmAutobakeFactory(mtrDbPool):
    ## f_rpm_autobake
    f_rpm_autobake= util.BuildFactory()
    f_rpm_autobake.addStep(steps.SetProperty(property="dockerfile", value=util.Interpolate("%(kw:url)s", url=dockerfile), description="dockerfile"))
    f_rpm_autobake.workdir=f_rpm_autobake.workdir + "/padding_for_CPACK_RPM_BUILD_SOURCE_DIRS_PREFIX/"
    f_rpm_autobake.addStep(steps.ShellCommand(name='fetch packages for MariaDB-compat', command=["sh", "-c", util.Interpolate('wget --no-check-certificate -cO ../MariaDB-shared-5.3.%(kw:arch)s.rpm "https://ci.mariadb.org/helper_files/mariadb-shared-5.3-%(kw:arch)s.rpm" && wget -cO ../MariaDB-shared-10.1.%(kw:arch)s.rpm "https://ci.mariadb.org/helper_files/mariadb-shared-10.1-kvm-rpm-%(kw:rpm_type)s-%(kw:arch)s.rpm"', arch=getArch, rpm_type=util.Property('rpm_type'))], doStepIf=hasCompat))
    f_rpm_autobake.addStep(downloadSourceTarball())
    f_rpm_autobake.addStep(steps.ShellCommand(command=util.Interpolate("tar -xvzf /mnt/packages/%(prop:tarbuildnum)s_%(prop:mariadb_version)s.tar.gz --strip-components=1")))
    f_rpm_autobake.addStep(steps.ShellCommand(command="ls .."))
    # build steps
    f_rpm_autobake.addStep(steps.ShellCommand(logfiles={'CMakeCache.txt': 'CMakeCache.txt'}, name="cmake", command=
        ["sh", "-c", util.Interpolate("export PATH=/usr/lib/ccache:/usr/lib64/ccache:$PATH && cmake . -DBUILD_CONFIG=mysql_release -DRPM=%(kw:rpm_type)s -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache  %(kw:mtr_additional_args)s", mtr_additional_args=util.Property('mtr_additional_args', default=''), rpm_type=util.Property('rpm_type'))], env={'CCACHE_DIR':'/mnt/ccache'}, description="cmake"))
    f_rpm_autobake.addStep(steps.Compile(command=
        ["sh", "-xc", util.Interpolate("""
            mkdir -p rpms srpms
            if grep -qw CPACK_RPM_SOURCE_PKG_BUILD_PARAMS CPackSourceConfig.cmake; then
                make package_source
                mv *.src.rpm srpms/
            fi
            export PATH=/usr/lib/ccache:/usr/lib64/ccache:$PATH && make -j %(kw:jobs)s package
        """, jobs=util.Property('jobs', default='$(getconf _NPROCESSORS_ONLN)'))], env={'CCACHE_DIR':'/mnt/ccache'}, description="make package"))
    # list rpm contents
    f_rpm_autobake.addStep(steps.ShellCommand(command=
        ['sh', '-c', 'for rpm in *.rpm; do echo $rpm ; rpm -q --qf "[%{FILEMODES:perms} %{FILEUSERNAME} %{FILEGROUPNAME} .%-36{FILENAMES}\n]" $rpm; echo "------------------------------------------------"; done'], description="list rpm contents"))
    # upload binaries
    f_rpm_autobake.addStep(steps.SetPropertyFromCommand(command="ls -1 *.rpm", extract_fn=ls2string))
    f_rpm_autobake.addStep(steps.ShellCommand(command=
        ["bash", "-xc", util.Interpolate("""
            if [ -e MariaDB-shared-10.1.*.rpm ]; then
               rm MariaDB-shared-10.1.*.rpm
            fi
            cp `ls -1 *.rpm` rpms/
            find srpms -type f -exec sha256sum {} \; | sort > sha256sums.txt
            find rpms -type f -exec sha256sum {} \; | sort >> sha256sums.txt
        """)]))
    #f_rpm_autobake.addStep(steps.MultipleFileUpload(workersrcs=util.Property('packages'),
    #    masterdest=util.Interpolate('/srv/buildbot/packages/' + '%(prop:tarbuildnum)s' + '/' + '%(prop:buildername)s'), mode=0o755, url=util.Interpolate('https://ci.mariadb.org/' + "%(prop:tarbuildnum)s" + "/" + '%(prop:buildername)s' + "/"), doStepIf=lambda step: hasFiles(step) and savePackage(step)))
    f_rpm_autobake.addStep(steps.ShellCommand(name='save_packages', timeout=7200, haltOnFailure=True, command=util.Interpolate('mkdir -p ' + '/packages/' + '%(prop:tarbuildnum)s' + '/' + '%(prop:buildername)s'+ ' && cp -r rpms srpms sha256sums.txt' + ' /packages/' + '%(prop:tarbuildnum)s' + '/' + '%(prop:buildername)s' + '/' +  ' && sync /packages/' + '%(prop:tarbuildnum)s'), doStepIf=lambda step: hasFiles(step) and savePackage(step)))
    f_rpm_autobake.addStep(steps.Trigger(name='install', schedulerNames=['s_install'], waitForFinish=True, updateSourceStamp=False,
        set_properties={"tarbuildnum" : Property("tarbuildnum"), "mariadb_version" : Property("mariadb_version"), "master_branch" : Property("master_branch"), "parentbuildername": Property("buildername")}, doStepIf=lambda step: hasInstall(step) and savePackage(step) and hasFiles(step)))
    f_rpm_autobake.addStep(steps.Trigger(name='major-minor-upgrade', schedulerNames=['s_upgrade'], waitForFinish=True, updateSourceStamp=False,
        set_properties={"tarbuildnum" : Property("tarbuildnum"), "mariadb_version" : Property("mariadb_version"), "master_branch" : Property("master_branch"), "parentbuildername": Property("buildername")}, doStepIf=lambda step: hasUpgrade(step) and savePackage(step) and hasFiles(step)))
    f_rpm_autobake.addStep(steps.ShellCommand(name="cleanup", command="rm -r * .* 2> /dev/null || true", alwaysRun=True))
    return f_rpm_autobake

