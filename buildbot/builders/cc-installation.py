serverVersionToInstallCc= "11.0"
linux_shallow_ccinstall= """
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
cc_repoinstall= repo_install(serverVersionToInstallCc) 
linux_ccinstall= cc_repoinstall + linux_shallow_ccinstall
