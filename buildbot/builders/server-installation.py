serverVersionToInstall= "10.11"

debubuntu_versionid= """
if LSB_VID=$(lsb_release -sr 2> /dev/null); then
  VERSION_ID=$(sed -e "s/\.//g" <<< "$LSB_VID")
  ID=$(lsb_release -si  | tr '[:upper:]' '[:lower:]')
  ID=${ID:0:3}
fi
"""

sles15server="https://dlm.mariadb.com/4405729/MariaDB/mariadb-10.6.23/yum/sles/15/x86_64/rpms/MariaDB-server-10.6.23-1.x86_64.rpm"
sles15client="https://dlm.mariadb.com/4405710/MariaDB/mariadb-10.6.23/yum/sles/15/x86_64/rpms/MariaDB-client-10.6.23-1.x86_64.rpm"
sles15common="https://dlm.mariadb.com/4405731/MariaDB/mariadb-10.6.23/yum/sles/15/x86_64/rpms/MariaDB-common-10.6.23-1.x86_64.rpm"
sles12server="https://dlm.mariadb.com/4405823/MariaDB/mariadb-10.6.23/yum/sles/12/x86_64/rpms/MariaDB-server-10.6.22-1.x86_64.rpm"
sles12client="https://dlm.mariadb.com/4405871/MariaDB/mariadb-10.6.23/yum/sles/12/x86_64/rpms/MariaDB-client-10.6.22-1.x86_64.rpm"
sles12common="https://dlm.mariadb.com/4405838/MariaDB/mariadb-10.6.23/yum/sles/12/x86_64/rpms/MariaDB-common-10.6.22-1.x86_64.rpm"

def serverinstall_from_url(url, url_client, url_common):
    return """
COMMON_RPM=""" + url_common + """
COMMON_FILE=$(basename "$COMMON_RPM")
wget -O "$COMMON_FILE" "$COMMON_RPM"
sudo zypper --no-gpg-checks install -y "$COMMON_FILE"
RPM_URL=""" + url + """
RPM_FILENAME=$(basename "$RPM_URL")
wget -O "$RPM_FILENAME" "$RPM_URL"
CLIENT_URL=""" + url_client + """
CLIENT_FILE=$(basename "$CLIENT_URL")
wget -O "$CLIENT_FILE" "$CLIENT_URL"
sudo zypper --no-gpg-checks install -y "$CLIENT_FILE"
#sudo zypper --no-gpg-checks install -y "$RPM_FILENAME"
sudo rpm -i --nodeps "$RPM_FILENAME"
sudo systemctl start mariadb
cd ..
pwd
sudo mysqladmin -u root password ''
sudo mariadb -e "SELECT * FROM mysql.user"
"""

def sles_serverinstall(version):
    if version == 12:
        return serverinstall_from_url(sles12server, sles12client, sles12common)
    else: #version == 15
        return serverinstall_from_url(sles15server, sles15client, sles15common)

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
  ;; esac
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
DISABLEFB="/etc/my.cnf.d/disable-feedback.cnf"
if [ -e "/etc/yum.repos.d/mariadb.repo" ]; then
  if sudo touch "$DISABLEFB"; then
    echo "[mariadb]" | sudo tee "$DISABLEFB"
    echo "feedback=OFF" | sudo tee -a "$DISABLEFB"
  fi
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
  sudo DEBIAN_FRONTEND=noninteractive apt install -y mariadb-server
fi

if [ -e "/etc/zypp/repos.d/mariadb.repo" ]; then
  if sudo touch "$DISABLEFB"; then
    echo "[mariadb]" | sudo tee "$DISABLEFB"
    echo "feedback=OFF" | sudo tee -a "$DISABLEFB"
  fi
  #sudo zypper refresh
  VERSIONS_LIST=$(zypper --non-interactive search --details "MariaDB-server")
  echo $VERSIONS_LIST
  LATEST_PACKAGE_VER=$(echo $VERSIONS_LIST | awk '/^v / {print $2" "$3}' | sort -V |sort -V | tail -n 1)
  read -r ACTUAL_PACKAGE_NAME LATEST_VERSION <<< "$LATEST_PACKAGE_VER"

  sudo zypper --auto-agree-with-licenses install -y "MariaDB-servera=${LATEST_VERSION}"
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

