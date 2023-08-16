serverVersionToInstallCc= "11.0"
linux_ccinstall= """
# Installing server to run tests
if [ -e /usr/bin/apt ] ; then
  sudo apt update
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
    sudo add-apt-repository -y 'deb [arch=amd64,arm64,i386,ppc64el] https://mirrors.ukfast.co.uk/sites/mariadb/repo/""" + serverVersionToInstallCc + """/ubuntu xenial main'
  fi
  if grep -i groovy /etc/os-release ; then
    USEAPT=1
    sudo apt-get install -y software-properties-common
    sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
    sudo add-apt-repository -y 'deb [arch=amd64,arm64,i386,ppc64el] https://mirrors.ukfast.co.uk/sites/mariadb/repo/""" + serverVersionToInstallCc + """/ubuntu groovy main'
  fi
  if grep -i impish /etc/os-release ; then
    USEAPT=1
    sudo apt-get install -y software-properties-common
    sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
    sudo add-apt-repository -y 'deb [arch=amd64,arm64,i386,ppc64el] https://mirrors.ukfast.co.uk/sites/mariadb/repo/""" + serverVersionToInstallCc + """/ubuntu impish main'
  fi
  if grep -i hirsute /etc/os-release ; then
    USEAPT=1
    sudo apt-get install -y software-properties-common
    sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
    sudo add-apt-repository -y 'deb [arch=amd64,arm64,i386,ppc64el] https://mirrors.ukfast.co.uk/sites/mariadb/repo/""" + serverVersionToInstallCc + """/ubuntu hirsute main'
  fi
fi

if [ -e "/etc/yum.repos.d/mariadb.repo" ]; then
  if ! sudo dnf install -y ; then
    sudo yum install -y MariaDB-devel;
    sudo rpm -ql MariaDB-devel
  else
    sudo dnf repoquery -l MariaDB-devel
  fi
fi

if [ ! -z "$USEAPT" ] || [ -e "/etc/apt/sources.list.d/mariadb.list" ]; then
  sudo apt update
  sudo apt install -y apt-transport-https
  sudo apt install -y libmariadb-dev
  dpkg -L libmariadb-dev
fi

if [ -e "/etc/zypp/repos.d/mariadb.repo" ]; then
  sudo zypper install -y MariaDB-shared
fi
"""

