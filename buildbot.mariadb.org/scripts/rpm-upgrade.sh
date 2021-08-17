#!/bin/bash

set -xv
case "$branch" in
*galera*)
  if [[ "$test_mode" == "all" ]] ; then
    echo "Upgrade warning: the test in 'all' mode is not executed for galera branches"
    exit
  fi
  ;;
$development_branch)
  if [[ "$test_mode" != "server" ]] ; then
    echo "Upgrade warning: the test in 'all' or 'deps' mode is not executed for non-stable branches"
    exit
  fi
  ;;
esac
package_version=`ls rpms/MariaDB-server-[0-9]* | head -n 1 | sed -e 's/.*MariaDB-server-\([0-9]*\.[0-9]*\.[0-9]*\).*/\\1/'`
prev_major_version=$major_version
# For now we rely on major_version being 10.1 or higher, can add a check later
if [[ "$test_type" == "major" ]] ; then
    minor_version_num=`echo $major_version | sed -e 's/10\.\([0-9]*\)/\\1/'`
    ((prev_minor_version_num = minor_version_num - 1))
    prev_major_version=10.$prev_minor_version_num
fi
if [[ "$distro" == "sles123" ]] ; then
    distro="sles12"
fi
repo_dist_arch=$distro-$arch
echo "Architecture and distribution based on VM name: $repo_dist_arch"
echo "Test properties"
echo "  Systemd capability     $systemdCapability"
echo "  Test type              $test_type"
echo "  Test mode              $test_mode"
echo "  Major version          $major_version"
echo "  Previous major version $prev_major_version"
#===============
# This test can be performed in four modes:
# - 'server' -- only mariadb-server is installed (with whatever dependencies it pulls) and upgraded.
# - 'all'    -- all provided packages are installed and upgraded, except for Columnstore
# - 'deps'   -- only a limited set of main packages is installed and upgraded,
#               to make sure upgrade does not require new dependencies
# - 'columnstore' -- mariadb-server and mariadb-plugin-columnstore are installed
#===============
echo "Current test mode: $test_mode"
#============
# Environment
#============
rpm -qa | grep -iE 'maria|mysql|galera'
cat /etc/*release
uname -a
df -kT
#========================================
# Check whether a previous version exists
#========================================
if ! wget http://yum.mariadb.org/$prev_major_version/$repo_dist_arch/repodata -O repodata.list
then
  echo "Upgrade warning: could not find the 'repodata' folder for a previous version in MariaDB repo, skipping the test"
  exit
fi
#===============================================
# Define the list of packages to install/upgrade
#===============================================
case $test_mode in
all|deps|columnstore)
  primary_xml=`grep 'primary.xml.gz' repodata.list | sed -e 's/.*href="\(.*-primary.xml\)\.gz\".*/\\1/'`
  wget http://yum.mariadb.org/$prev_major_version/$repo_dist_arch/repodata/$primary_xml.gz
  if [[ $? != 0 ]] ; then
    echo "ERROR: Couldn't download primary.xml.gz from the repository"
    exit 1
  fi
  gunzip $primary_xml.gz
  if [[ "$test_mode" == "all" ]] ; then
    if grep -i columnstore $primary_xml > /dev/null ; then
      echo "Upgrade warning: Due to MCOL-4120 and other issues, Columnstore upgrade will be tested separately"
    fi
    package_list=`grep -A 1 '<package type="rpm"' $primary_xml | grep MariaDB | grep -viE 'galera|columnstore' | sed -e 's/<name>//' | sed -e 's/<\/name>//' | sort | uniq | xargs`
  elif [[ "$test_mode" == "deps" ]] ; then
    package_list=`grep -A 1 '<package type="rpm"' $primary_xml | grep -iE 'MariaDB-server|MariaDB-test|MariaDB-client|MariaDB-common|MariaDB-compat' | sed -e 's/<name>//' | sed -e 's/<\/name>//' | sort | uniq | xargs`
  elif [[ "$test_mode" == "columnstore" ]] ; then
    if ! grep columnstore $primary_xml > /dev/null ; then
      echo "Upgrade warning: Columnstore was not found in the released packages, the test will not be run"
      exit
    fi
    package_list="MariaDB-server MariaDB-columnstore-engine"
  fi
  if [[ $arch == ppc* ]] ; then
    package_list=`echo $package_list | xargs -n1 | sed -e 's/MariaDB-compat//gi' | xargs`
  fi
  ;;
server)
  package_list="MariaDB-server MariaDB-client"
  ;;
*)
  echo "ERROR: unknown test mode: $test_mode"
  exit 1
esac
echo "Package_list: $package_list"
#======================================================================
# Prepare yum/zypper configuration for installation of the last release
#======================================================================
if which zypper ; then
  package_manager=zypper
  repo_location=/etc/zypp/repos.d
  install_command="zypper --no-gpg-checks install --from mariadb -y"
  cleanup_command="zypper clean --all"
  remove_command="zypper remove -y"
  # Since there is no reasonable "upgrade" command in zypper which would
  # pick up RPM files needed to upgrade existing packages, we have to use "install".
  # However, if we run "install *.rpm", it will install all packages, regardless
  # the test mode, and we will get a lot of differences in contents after upgrade
  # (more plugins, etc.). So, instead for each package that we are going to install,
  # we'll also find an RPM file which provides it, and will use its name in
  # in the "upgrade" (second install) command
  if [[ "$test_mode" == "all" ]] ; then
    rm -f rpms/*columnstore*.rpm
    rpms_for_upgrade="rpms/*.rpm"
    case "$branch" in
    *10.[2-9]*)
      ;;
    *)
      echo "Upgrade warning: Due to MDEV-14560 (only fixed in 10.2+) an extra service restart will be performed after upgrade"
      extra_restart_after_upgrade="yes"
      ;;
    esac
  else
    rpms_for_upgrade=""
    extra_restart_after_upgrade="yes"
    for p in $package_list ; do
      for f in rpms/*.rpm ; do
	if rpm -qp $f --provides | grep -i "^$p =" ; then
	  rpms_for_upgrade="$rpms_for_upgrade $f"
	  break
	fi
      done
    done
  fi
  upgrade_command="zypper --no-gpg-checks install -y $rpms_for_upgrade"
# As of now (February 2018), RPM packages do not support major upgrade.
# To imitate it, we will remove previous packages and install new ones.
elif which yum ; then
  package_manager=yum
  repo_location=/etc/yum.repos.d
  install_command="yum -y --nogpgcheck install"
  cleanup_command="yum clean all"
  upgrade_command="yum -y --nogpgcheck upgrade rpms/*.rpm"
  if [[ "$test_type" == "major" ]] ; then
    upgrade_command="yum -y --nogpgcheck install rpms/*.rpm"
  fi
  if yum autoremove 2>&1 |grep -q 'need to be root'; then
    remove_command="yum -y autoremove"
  else
    remove_command="yum -y remove"
  fi
else
  echo "ERROR: could not find package manager"
  exit 1
fi
if [[ "$test_mode" == "columnstore" ]] ; then
  echo "Upgrade warning: Due to MCOL-4120 an extra service restart will be performed after upgrade"
  extra_restart_after_upgrade="yes"
fi
extra_restart_after_upgrade="yes"
ls $repo_location/* | grep -iE '(maria|galera)' | xargs -r sudo rm -f
sudo sh -c "echo '[mariadb]
name=MariaDB
baseurl=http://yum.mariadb.org/$prev_major_version/$repo_dist_arch
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1' > $repo_location/MariaDB.repo"
# Add fix for MDEV-20673 to rhel8/centos8 repo
case $HOSTNAME in
  rhel8*|centos8*) sudo sh -c "echo 'module_hotfixes = 1' >> $repo_location/MariaDB.repo";;
esac
# Workaround for TODO-1479 (errors upon reading from SUSE repos)
#sudo rm -rf /etc/zypp/repos.d/SUSE_Linux_Enterprise_Server_12_SP3_x86_64:SLES12-SP3-Updates.repo /etc/zypp/repos.d/SUSE_Linux_Enterprise_Server_12_SP3_x86_64:SLES12-SP3-Pool.repo
sudo sh -c "$cleanup_command"
#=========================
# Install previous release
#=========================
sudo sh -c "$install_command $package_list"
if [[ $? -ne 0 ]] ; then
  echo "ERROR: Installation of a previous release failed, see the output above"
  exit 1
fi
#==========================================================================
# Start the server, check that it is functioning and create some structures
#==========================================================================
case `expr "$prev_major_version" '<' "10.1"`"$systemdCapability" in
0yes)
  sudo systemctl start mariadb
  if [[ "$distro" != *"sles"* ]] && [[ "$distro" != *"suse"* ]] ; then
    sudo systemctl enable mariadb
  else
    echo "Upgrade warning: due to MDEV-23044 mariadb service won't be enabled in the test"
  fi
  sudo systemctl status mariadb --no-pager
  ;;
*)
  sudo /etc/init.d/mysql start
  ;;
esac
if [[ $? -ne 0 ]] ; then
  echo "ERROR: Server startup failed"
  sudo cat /var/log/messages | grep -iE 'mysqld|mariadb'
  sudo cat /var/lib/mysql/*.err
  exit 1
fi
if [[ "$prev_major_version" > "10.3" ]] ; then
# 10.4+ uses unix_socket by default, hence sudo,
# and also might have simple_password_check plugin, hence non-default password
  sudo mysql -e "set password= PASSWORD('S1mpl-pw')"
  password_option="-pS1mpl-pw"
fi
# All the commands below should succeed
set -e
mysql -uroot $password_option -e "CREATE DATABASE db"
mysql -uroot $password_option -e "CREATE TABLE db.t_innodb(a1 SERIAL, c1 CHAR(8)) ENGINE=InnoDB; INSERT INTO db.t_innodb VALUES (1,'foo'),(2,'bar')"
mysql -uroot $password_option -e "CREATE TABLE db.t_myisam(a2 SERIAL, c2 CHAR(8)) ENGINE=MyISAM; INSERT INTO db.t_myisam VALUES (1,'foo'),(2,'bar')"
mysql -uroot $password_option -e "CREATE TABLE db.t_aria(a3 SERIAL, c3 CHAR(8)) ENGINE=Aria; INSERT INTO db.t_aria VALUES (1,'foo'),(2,'bar')"
mysql -uroot $password_option -e "CREATE TABLE db.t_memory(a4 SERIAL, c4 CHAR(8)) ENGINE=MEMORY; INSERT INTO db.t_memory VALUES (1,'foo'),(2,'bar')"
mysql -uroot $password_option -e "CREATE ALGORITHM=MERGE VIEW db.v_merge AS SELECT * FROM db.t_innodb, db.t_myisam, db.t_aria"
mysql -uroot $password_option -e "CREATE ALGORITHM=TEMPTABLE VIEW db.v_temptable AS SELECT * FROM db.t_innodb, db.t_myisam, db.t_aria"
mysql -uroot $password_option -e "CREATE PROCEDURE db.p() SELECT * FROM db.v_merge"
mysql -uroot $password_option -e "CREATE FUNCTION db.f() RETURNS INT DETERMINISTIC RETURN 1"
if [[ "$test_mode" == "columnstore" ]] ; then
  mysql -uroot $password_option -e "CREATE TABLE db.t_columnstore(a INT, c VARCHAR(8)) ENGINE=ColumnStore; SHOW CREATE TABLE db.t_columnstore; INSERT INTO db.t_columnstore VALUES (1,'foo'),(2,'bar')"
fi
set +e
#====================================================================================
# Store information about server version and available plugins/engines before upgrade
#====================================================================================
mysql -uroot $password_option --skip-column-names -e "select @@version" | awk -F'-' '{ print $1 }' > /tmp/version.old
old_version=`cat /tmp/version.old`
# If the tested branch has the same version as the public repository,
# upgrade won't work properly. For releasable branches, we will return an error
# urging to bump the version number. For other branches, we will abort the test
# with a warning (which nobody will read). This is done upon request from
# development, as temporary branches might not be rebased in a timely manner
if [ "$package_version" == "$old_version" ] ; then
    echo "ERROR: Server version $package_version has already been released. Bump the version number!"
    for b in $releasable_branches ; do
	if [ "$b" == "$branch" ] ; then
	    exit 1
	fi
    done
    echo "Upgrade warning: The test will be skipped, as upgrade will not work properly"
    exit
fi
mysql -uroot $password_option --skip-column-names -e "select engine, support, transactions, savepoints from information_schema.engines" | sort > /tmp/engines.old
case "$prev_major_version" in
5.5)
  mysql -uroot $password_option --skip-column-names -e "show plugins" | sort > /tmp/plugins.old
  ;;
10.[0-9])
  mysql -uroot $password_option --skip-column-names -e "select plugin_name, plugin_status, plugin_type, plugin_library, plugin_license from information_schema.all_plugins" | sort > /tmp/plugins.old
  ;;
*)
  echo "ERROR: unknown major version: $prev_major_version"
  exit 1
  ;;
esac
# Store dependency information for old binaries/libraries:
# - names starting with "mysql*" in the directory where mysqld is located;
# - names starting with "mysql*" in the directory where mysql is located;
# - everything in the plugin directories installed by any MariaDB packages
set +x
for i in `sudo which mysqld | sed -e 's/mysqld$/mysql\*/'` `which mysql | sed -e 's/mysql$/mysql\*/'` `rpm -ql \`rpm -qa | grep MariaDB | xargs\` | grep -v 'mysql-test' | grep -v '/debug/' | grep '/plugin/' | sed -e 's/[^\/]*$/\*/' | sort | uniq | xargs`; do echo "=== $i" ; ldd $i | sort | sed 's/(.*)//' ; done > /home/buildbot/ldd.old
set -x
#======================================================================
# Prepare yum/zypper configuration for installation of the new packages
#======================================================================
set -e
if [[ "$test_type" == "major" ]] ; then
  echo
  echo "Remove old packages for major upgrade"
  echo
  packages_to_remove=`rpm -qa | grep 'MariaDB-' | awk -F'-' '{print $1"-"$2}' | xargs`
  sudo sh -c "$remove_command $packages_to_remove"
  rpm -qa | grep -iE 'maria|mysql' || true
fi
if [[ "$test_mode" == "deps" ]] ; then
  sudo mv $repo_location/MariaDB.repo /tmp
  sudo rm -rf $repo_location/*
  sudo mv /tmp/MariaDB.repo $repo_location/
  sudo sh -c "$cleanup_command"
fi
#=========================
# Install the new packages
#=========================
# Between 10.3 and 10.4(.2), required galera version changed from galera(-3) to galera-4.
# It means that there will be no galera-4 in the "old" repo, and it's not among the local RPMs.
# So, we need to add a repo for it
if [[ "$test_type" == "major" ]] && [[ "$major_version" > "10.3" ]] && [[ "$prev_major_version" < "10.4" ]] ; then
  sudo sh -c "echo '[galera]
name=Galera
baseurl=http://yum.mariadb.org/galera/repo4/rpm/$repo_dist_arch
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1' > $repo_location/galera.repo"
fi
sudo sh -c "$upgrade_command"
set +e
#===================================================
# Check that no old packages have left after upgrade
#===================================================
# The check is only performed for all-package-upgrade, because
# for selective ones some implicitly installed packages might not be upgraded
if [[ "$test_mode" == "all" ]] ; then
  if [ "$is_main_tree" == "yes" ] ; then
    rpm -qa | grep -iE 'mysql|maria' | grep `cat /tmp/version.old`
  else
    rpm -qa | grep -iE 'mysql|maria' | grep `cat /tmp/version.old` | grep -v debuginfo
  fi
  if [[ $? -eq 0 ]] ; then
    echo "ERROR: Old packages have been found after upgrade"
    exit 1
  fi
fi
#================================
# Optionally (re)start the server
#================================
set -e
if [ "$test_type" == "major" ] ; then
  case "$systemdCapability" in
  yes)
    sudo systemctl start mariadb
    ;;
  no)
    sudo /etc/init.d/mysql start
    ;;
  esac
elif [ -n "$extra_restart_after_upgrade" ] ; then
  case "$systemdCapability" in
  yes)
    sudo systemctl restart mariadb
    ;;
  no)
    sudo /etc/init.d/mysql restart
    ;;
  esac
fi
#================================
# Make sure that the new server is running
#================================
if mysql -uroot $password_option -e "select @@version" | grep "$old_version" ; then
  echo "ERROR: The server was not upgraded or was not restarted after upgrade"
  exit 1
fi
#=====================================================================================
# Run mysql_upgrade for non-GA branches (minor upgrades in GA branches shouldn't need it)
#=====================================================================================
if [[ "$major_version" == $development_branch ]] || [[ "$test_type" == "major" ]] ; then
  mysql_upgrade -uroot $password_option
fi
set +e
#=====================================================================================
# Check that the server is functioning and previously created structures are available
#=====================================================================================
# All the commands below should succeed
set -e
mysql -uroot $password_option -e "select @@version, @@version_comment"
mysql -uroot $password_option -e "SHOW TABLES IN db"
mysql -uroot $password_option -e "SELECT * FROM db.t_innodb; INSERT INTO db.t_innodb VALUES (3,'foo'),(4,'bar')"
mysql -uroot $password_option -e "SELECT * FROM db.t_myisam; INSERT INTO db.t_myisam VALUES (3,'foo'),(4,'bar')"
mysql -uroot $password_option -e "SELECT * FROM db.t_aria; INSERT INTO db.t_aria VALUES (3,'foo'),(4,'bar')"
echo "If the next INSERT fails with a duplicate key error,"
echo "it is likely because the server was not upgraded or restarted after upgrade"
mysql -uroot $password_option -e "SELECT * FROM db.t_memory; INSERT INTO db.t_memory VALUES (1,'foo'),(2,'bar')"
mysql -uroot $password_option -e "SELECT COUNT(*) FROM db.v_merge"
mysql -uroot $password_option -e "SELECT COUNT(*) FROM db.v_temptable"
mysql -uroot $password_option -e "CALL db.p()"
mysql -uroot $password_option -e "SELECT db.f()"
if [[ "$test_mode" == "columnstore" ]] ; then
  mysql -uroot $password_option -e "SELECT * FROM db.t_columnstore; INSERT INTO db.t_columnstore VALUES (3,'foo'),(4,'bar')"
fi
set +e
#===================================================================================
# Store information about server version and available plugins/engines after upgrade
#===================================================================================
set -e
mysql -uroot $password_option --skip-column-names -e "select @@version" | awk -F'-' '{ print $1 }' > /tmp/version.new
mysql -uroot $password_option --skip-column-names -e "select engine, support, transactions, savepoints from information_schema.engines" | sort > /tmp/engines.new
cat /tmp/engines.new
case "$major_version" in
5.5)
  mysql -uroot $password_option --skip-column-names -e "show plugins" | sort > /tmp/plugins.new
  ;;
10.[0-9])
  mysql -uroot $password_option --skip-column-names -e "select plugin_name, plugin_status, plugin_type, plugin_library, plugin_license from information_schema.all_plugins" | sort > /tmp/plugins.new
  ;;
esac
# Dependency information for new binaries/libraries
set +x
for i in `sudo which mysqld | sed -e 's/mysqld$/mysql\*/'` `which mysql | sed -e 's/mysql$/mysql\*/'` `rpm -ql \`rpm -qa | grep MariaDB | xargs\` | grep -v 'mysql-test' | grep -v '/debug/' | grep '/plugin/' | sed -e 's/[^\/]*$/\*/' | sort | uniq | xargs`; do echo "=== $i" ; ldd $i | sort | sed 's/(.*)//' ; done > /home/buildbot/ldd.new
set -x
case "$systemdCapability" in
yes)
  ls -l /usr/lib/systemd/system/mariadb.service
  ls -l /etc/systemd/system/mariadb.service.d/migrated-from-my.cnf-settings.conf
  ls -l /etc/init.d/mysql || true
  systemctl status mariadb.service --no-pager
  systemctl status mariadb --no-pager
  # Not done for SUSE due to MDEV-23044
  if [[ "$distro" != *"sles"* ]] && [[ "$distro" != *"suse"* ]] ; then
    # Major upgrade for RPMs is remove / install, so previous configuration
    # could well be lost
    if [[ "$test_type" == "major" ]] ; then
      sudo systemctl enable mariadb
    fi
    systemctl is-enabled mariadb
    systemctl status mysql --no-pager
    systemctl status mysqld --no-pager
  fi
  ;;
no)
  echo "Steps related to systemd will be skipped"
  ;;
*)
  echo "ERROR: It should never happen, check your configuration (systemdCapability property is not set or is set to a wrong value)"
  exit 1
  ;;
esac
set +e
# Until $development_branch is GA, the list of plugins/engines might be unstable, skipping the check
# For major upgrade, no point to do the check at all
if [[ "$major_version" != $development_branch ]] && [[ "$test_type" != "major" ]] ; then
  # This output is for informational purposes
  diff -u /tmp/engines.old /tmp/engines.new
  diff -u /tmp/plugins.old /tmp/plugins.new
  # Only fail if there are any disappeared/changed engines or plugins
  disappeared_or_changed=`comm -23 /tmp/engines.old /tmp/engines.new | wc -l`
  if [[ $disappeared_or_changed -ne 0 ]] ; then
    echo "ERROR: the lists of engines in the old and new installations differ"
    exit 1
  fi
  disappeared_or_changed=`comm -23 /tmp/plugins.old /tmp/plugins.new | wc -l`
  if [[ $disappeared_or_changed -ne 0 ]] ; then
    echo "ERROR: the lists of available plugins in the old and new installations differ"
    exit 1
  fi
  if [ "$test_mode" == "all" ] ; then
    set -o pipefail
    if wget --timeout=20 --no-check-certificate https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot/baselines/ldd.${major_version}.${distro}.${arch} -O /tmp/ldd.baseline > /dev/null ; then
      ldd_baseline=/tmp/ldd.baseline
    else
      ldd_baseline=/home/buildbot/ldd.old
    fi
    diff -U1000 $ldd_baseline /home/buildbot/ldd.new | ( grep -E '^[-+]|^ =' || true )
    if [[ $? -ne 0 ]] ; then
      echo "ERROR: something has changed in the dependencies of binaries or libraries. See the diff above"
      exit 1
    fi
  fi
  set +o pipefail
fi
diff -u /tmp/version.old /tmp/version.new
if [[ $? -eq 0 ]] ; then
  echo "ERROR: server version has not changed after upgrade"
  echo "It can be a false positive if we forgot to bump version after release,"
  echo "or if it is a development tree is based on an old version"
  exit 1
fi
echo "Done"
