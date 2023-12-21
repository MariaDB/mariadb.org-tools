serverVersionToInstall= "10.6"

debubuntu_versionid= """
if LSB_VID=$(lsb_release -sr 2> /dev/null); then
  VERSION_ID=$(sed -e "s/\.//g" <<< "$LSB_VID")
  ID=$(lsb_release -si  | tr '[:upper:]' '[:lower:]')
  ID=${ID:0:3}
fi
"""
def repo_install(version):
    return """
# Installing server to run tests
if [ -e /usr/bin/apt ] ; then
  if ! sudo apt update ; then
    echo "Warning - apt update failed"
  fi
# This package is required to run following script
  sudo apt install -y apt-transport-https
  sudo apt install -y curl
fi

source /etc/os-release

SPACKAGE_NAME=MariaDB-server
if [ "$ID" = "rocky" ]; then
  SPACKAGE_NAME=mariadb-server
fi

case $HOSTNAME in rhel*)
  ID=rhel
  VERSION_ID=$(cat /etc/redhat-release | awk '{print $6}' | sed -e "s/\..*//g")

  sudo subscription-manager refresh 
  if [ $VERSION_ID == 9 ]; then
    sudo subscription-manager repos --enable=codeready-builder-for-rhel-9-x86_64-rpms
  fi ;; esac
if ! curl -LsS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --skip-maxscale; then
  if [ -e /etc/fedora-release ]; then
    SPACKAGE_NAME=mariadb-server
    case $ID$VERSION_ID in fedora35) 
        sudo sh -c "echo \\"#galera test repo
[galera]
name = galera
baseurl = https://yum.mariadb.org/galera/repo4/rpm/$ID$VERSION_ID-amd64
gpgkey = https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck = 1\\" > /etc/yum.repos.d/galera.repo"
        VERSION_ID=34 ;; esac
    sudo sh -c "echo \\"#MariaDB.Org repo
[mariadb]
name = MariaDB
#baseurl = http://yum.mariadb.org/10.5/$ID$VERSION_ID-amd64
baseurl = http://yum.mariadb.org/10.5/$ID$VERSION_ID-amd64
gpgkey = https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck = 1\\" > /etc/yum.repos.d/mariadb.repo"
    sudo rpm --import https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
    sudo dnf remove -y mariadb-connector-c-config
  fi
  if grep -i xenial /etc/os-release ; then
    USEAPT=1
    sudo apt-get install -y software-properties-common gnupg-curl
    sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
    sudo add-apt-repository -y 'deb [arch=amd64,arm64,i386,ppc64el] https://mirrors.ukfast.co.uk/sites/mariadb/repo/""" + version + """/ubuntu xenial main'
  fi
  if grep -i groovy /etc/os-release ; then
    USEAPT=1
    sudo apt-get install -y software-properties-common
    sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
    sudo add-apt-repository -y 'deb [arch=amd64,arm64,i386,ppc64el] https://mirrors.ukfast.co.uk/sites/mariadb/repo/""" + version + """/ubuntu groovy main'
  fi
  if grep -i impish /etc/os-release ; then
    USEAPT=1
    sudo apt-get install -y software-properties-common
    sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
    sudo add-apt-repository -y 'deb [arch=amd64,arm64,i386,ppc64el] https://mirrors.ukfast.co.uk/sites/mariadb/repo/""" + version + """/ubuntu impish main'
  fi
  if grep -i hirsute /etc/os-release ; then
    USEAPT=1
    sudo apt-get install -y software-properties-common
    sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
    sudo add-apt-repository -y 'deb [arch=amd64,arm64,i386,ppc64el] https://mirrors.ukfast.co.uk/sites/mariadb/repo/""" + version + """/ubuntu hirsute main'
  fi
fi
""" + debubuntu_versionid

linux_shallow_serverinstall= """
if [ -e "/etc/yum.repos.d/mariadb.repo" ]; then
  if ! sudo dnf install -y $SPACKAGE_NAME; then
    sudo yum install -y $SPACKAGE_NAME
  fi
  sudo systemctl start mariadb
fi

if [ ! -z "$USEAPT" ] || [ -e "/etc/apt/sources.list.d/mariadb.list" ]; then
  if ! sudo apt update ; then
    echo "Warning - apt update failed"
  fi
#  sudo apt install -y apt-transport-https
  sudo apt install -y mariadb-server
fi

if [ -e "/etc/zypp/repos.d/mariadb.repo" ]; then
  sudo zypper install -y MariaDB-server
  sudo systemctl start mariadb
fi

sudo mariadb -u root -e "select version(),@@port, @@socket"
sudo mariadb -u root -e "set password=\\"\\""
sudo mariadb -u root -e "DROP DATABASE IF EXISTS test"
sudo mariadb -u root -e "CREATE DATABASE test"
sudo mariadb -u root -e "SELECT * FROM mysql.user"
SOCKETPATH=$(mariadb -u root test -N -B -e "select @@socket")
echo $SOCKETPATH

cd ..
"""
server_repoinstall= repo_install(serverVersionToInstall)
linux_serverinstall= server_repoinstall + linux_shallow_serverinstall

