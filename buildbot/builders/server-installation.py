serverVersionToInstall= "10.6"
linux_serverinstall= """
# Installing server to run tests
if [ -e /usr/bin/apt ] ; then
  if ! sudo apt update ; then
    echo "Warning - apt update failed"
  fi
# This package is required to run following script
  sudo apt install -y apt-transport-https
  sudo apt install -y curl
fi

case $HOSTNAME in rhel*) sudo subscription-manager refresh ;; esac

if ! curl -LsS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --skip-maxscale; then
  if [ -e /etc/fedora-release ]; then
    source /etc/os-release
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
    sudo add-apt-repository -y 'deb [arch=amd64,arm64,i386,ppc64el] https://mirrors.ukfast.co.uk/sites/mariadb/repo/""" + serverVersionToInstall + """/ubuntu xenial main'
  fi
  if grep -i groovy /etc/os-release ; then
    USEAPT=1
    sudo apt-get install -y software-properties-common
    sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
    sudo add-apt-repository -y 'deb [arch=amd64,arm64,i386,ppc64el] https://mirrors.ukfast.co.uk/sites/mariadb/repo/""" + serverVersionToInstall + """/ubuntu groovy main'
  fi
  if grep -i impish /etc/os-release ; then
    USEAPT=1
    sudo apt-get install -y software-properties-common
    sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
    sudo add-apt-repository -y 'deb [arch=amd64,arm64,i386,ppc64el] https://mirrors.ukfast.co.uk/sites/mariadb/repo/""" + serverVersionToInstall + """/ubuntu impish main'
  fi
  if grep -i hirsute /etc/os-release ; then
    USEAPT=1
    sudo apt-get install -y software-properties-common
    sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
    sudo add-apt-repository -y 'deb [arch=amd64,arm64,i386,ppc64el] https://mirrors.ukfast.co.uk/sites/mariadb/repo/""" + serverVersionToInstall + """/ubuntu hirsute main'
  fi
fi

if [ -e "/etc/yum.repos.d/mariadb.repo" ]; then
  if ! sudo dnf install -y MariaDB-server ; then
    sudo yum install -y MariaDB-server
  fi
  sudo systemctl start mariadb
fi

if [ ! -z "$USEAPT" ] || [ -e "/etc/apt/sources.list.d/mariadb.list" ]; then
  sudo apt update
  sudo apt install -y apt-transport-https
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

