### Libraries need for debian/autobake.sh
chrpath dh-apparmor dpatch libaio-dev libboost-dev libcrack2-dev \
libjemalloc-dev libjudy-dev libkrb5-dev libnuma-dev libpam0g-dev \
libpcre3-dev libreadline-gplv2-dev libsnappy-dev libsystemd-dev \
libxml2-dev unixodbc-dev uuid-dev


### Current state - have 10.4 over 10.1 installed
Over mariadb 10.1 installed mariadb-server-10.4
```bash
$ dpkg -l|grep -E "maria|mysql"
ii  libdbd-mysql-perl                              4.046-1                                             amd64        Perl5 database interface to the MariaDB/MySQL database
ii  libmariadb3:amd64                              1:10.4.24+maria~bionic                              amd64        MariaDB database client library
ii  libmariadbclient18                             1:10.4.24+maria~bionic                              amd64        Virtual package to satisfy external libmariadbclient18 depends
ii  libmysqlclient-dev                             5.7.37-0ubuntu0.18.04.1                             amd64        MySQL database development files
ii  libmysqlclient20:amd64                         5.7.37-0ubuntu0.18.04.1                             amd64        MySQL database client library
rc  mariadb-client-10.1                            1:10.1.44-0ubuntu0.18.04.1                          amd64        MariaDB database client binaries
ii  mariadb-client-10.4                            1:10.4.24+maria~bionic                              amd64        MariaDB database client binaries
ii  mariadb-client-core-10.4                       1:10.4.24+maria~bionic                              amd64        MariaDB database core client binaries
ii  mariadb-common                                 1:10.4.24+maria~bionic                              all          MariaDB database common files (e.g. /etc/mysql/mariadb.conf.d/)
ii  mariadb-server                                 1:10.4.24+maria~bionic                              all          MariaDB database server (metapackage depending on the latest version)
rc  mariadb-server-10.1                            1:10.1.44-0ubuntu0.18.04.1                          amd64        MariaDB database server binaries
ii  mariadb-server-10.4                            1:10.4.24+maria~bionic                              amd64        MariaDB database server binaries
ii  mariadb-server-core-10.4                       1:10.4.24+maria~bionic                              amd64        MariaDB database core server files
ii  mysql-common                                   1:10.4.24+maria~bionic                              all          MariaDB database common files (e.g. /etc/mysql/my.cnf)
```

#### How to inteprepret statuses ?
Each package has 3 chars (desired, current state and error), based on 
https://linuxprograms.wordpress.com/2010/05/11/status-dpkg-list/

`rc` - `r` package is marked for removal, `c`
`ii` - `i` package marked for install, `i` installed correctly
NOte that libmysqlclient-dev/client20:amdbd64 are not removed by 10.4 package

#### Uninstall 10.4:
- remove `mariadb-server` package
```bash
$ sudo apt remove mariadb-server
[sudo] password for anel: 
Čitam spiskove paketa... Done
Gradim stablo zavisnosti       
Reading state information... Done
The following packages were automatically installed and are no longer required:
  galera-4 libdbd-mysql-perl libdbi-perl libterm-readkey-perl mariadb-client-10.4 mariadb-client-core-10.4 mariadb-server-10.4 mariadb-server-core-10.4 socat
Use 'sudo apt autoremove' to remove them.
Slijedeći paketi će biti UKLONJENI:
  mariadb-server
0 upgraded, 0 newly installed, 1 to remove and 0 not upgraded.
After this operation, 10,2 kB disk space will be freed.
Da li želite nastaviti? [Y/n] ^C
```

- confirm it
```bash
$ dpkg -l|grep -E "mysql|maria"
ii  libdbd-mysql-perl                              4.046-1                                             amd64        Perl5 database interface to the MariaDB/MySQL database
ii  libmariadb3:amd64                              1:10.4.24+maria~bionic                              amd64        MariaDB database client library
ii  libmariadbclient18                             1:10.4.24+maria~bionic                              amd64        Virtual package to satisfy external libmariadbclient18 depends
ii  libmysqlclient-dev                             5.7.37-0ubuntu0.18.04.1                             amd64        MySQL database development files
ii  libmysqlclient20:amd64                         5.7.37-0ubuntu0.18.04.1                             amd64        MySQL database client library
rc  mariadb-client-10.1                            1:10.1.44-0ubuntu0.18.04.1                          amd64        MariaDB database client binaries
ii  mariadb-client-10.4                            1:10.4.24+maria~bionic                              amd64        MariaDB database client binaries
ii  mariadb-client-core-10.4                       1:10.4.24+maria~bionic                              amd64        MariaDB database core client binaries
ii  mariadb-common                                 1:10.4.24+maria~bionic                              all          MariaDB database common files (e.g. /etc/mysql/mariadb.conf.d/)
rc  mariadb-server-10.1                            1:10.1.44-0ubuntu0.18.04.1                          amd64        MariaDB database server binaries
ii  mariadb-server-10.4                            1:10.4.24+maria~bionic                              amd64        MariaDB database server binaries
ii  mariadb-server-core-10.4                       1:10.4.24+maria~bionic                              amd64        MariaDB database core server files
ii  mysql-common                                   1:10.4.24+maria~bionic                              all          MariaDB database common files (e.g. /etc/mysql/my.cnf)
```
- `autoremove` error,why?:
```bash
$ sudo apt autoremove
Removing mariadb-client-10.4 (1:10.4.24+maria~bionic) ...
Removing mariadb-client-core-10.4 (1:10.4.24+maria~bionic) ...
Removing mariadb-server-core-10.4 (1:10.4.24+maria~bionic) ...
dpkg: upozorenje: while removing mariadb-server-core-10.4, directory '/usr/share/mysql' not empty so not removed
```

- Note: still client-10.4 as an `rc` (what is a proper way to remove it? Again `remove`)
```bash
$ dpkg -l|grep -E "mysql|maria"
ii  libmariadb3:amd64                              1:10.4.24+maria~bionic                              amd64        MariaDB database client library
ii  libmariadbclient18                             1:10.4.24+maria~bionic                              amd64        Virtual package to satisfy external libmariadbclient18 depends
ii  libmysqlclient-dev                             5.7.37-0ubuntu0.18.04.1                             amd64        MySQL database development files
ii  libmysqlclient20:amd64                         5.7.37-0ubuntu0.18.04.1                             amd64        MySQL database client library
rc  mariadb-client-10.1                            1:10.1.44-0ubuntu0.18.04.1                          amd64        MariaDB database client binaries
rc  mariadb-client-10.4                            1:10.4.24+maria~bionic                              amd64        MariaDB database client binaries
ii  mariadb-common                                 1:10.4.24+maria~bionic                              all          MariaDB database common files (e.g. /etc/mysql/mariadb.conf.d/)
rc  mariadb-server-10.1                            1:10.1.44-0ubuntu0.18.04.1                          amd64        MariaDB database server binaries
rc  mariadb-server-10.4                            1:10.4.24+maria~bionic                              amd64        MariaDB database server binaries
ii  mysql-common                                   1:10.4.24+maria~bionic                              all          MariaDB database common files (e.g. /etc/mysql/my.cnf)
```

#### Purge rc packages
- Command to manually purge from `dpkg`:
```bash
$ dpkg -l|grep "^rc"|grep -E "maria|mysql"|cut -d " " -f 3
mariadb-client-10.1
mariadb-client-10.4
mariadb-server-10.1
mariadb-server-10.4
# This will remove all rc and ask to remove /var/lib/data from 10.4
$ dpkg -l|grep "^rc"|grep -E "maria|mysql"|cut -d " " -f 3|xargs sudo dpkg --purge
(Reading database ... 451785 files and directories currently installed.)
Purging configuration files for mariadb-client-10.1 (1:10.1.44-0ubuntu0.18.04.1) ...
Purging configuration files for mariadb-client-10.4 (1:10.4.24+maria~bionic) ...
Purging configuration files for mariadb-server-10.1 (1:10.1.44-0ubuntu0.18.04.1) ...
Purging configuration files for mariadb-server-10.4 (1:10.4.24+maria~bionic) ...
Processing triggers for systemd (237-3ubuntu10.53) ...
Processing triggers for ureadahead (0.100.0-21) ...
```
- List again:
$ dpkg -l|grep -E "mysql|maria"
ii  libmariadb3:amd64                              1:10.4.24+maria~bionic                              amd64        MariaDB database client library
ii  libmariadbclient18                             1:10.4.24+maria~bionic                              amd64        Virtual package to satisfy external libmariadbclient18 depends
ii  libmysqlclient-dev                             5.7.37-0ubuntu0.18.04.1                             amd64        MySQL database development files
ii  libmysqlclient20:amd64                         5.7.37-0ubuntu0.18.04.1                             amd64        MySQL database client library
ii  mariadb-common                                 1:10.4.24+maria~bionic                              all          MariaDB database common files (e.g. /etc/mysql/mariadb.conf.d/)
ii  mysql-common                                   1:10.4.24+maria~bionic                              all          MariaDB database common files (e.g. /etc/mysql/my.cnf)
```
- Observation: `mariadb-common`- depends on `mysql-common`
  However note that there is no `mariadbconf` (instead of `mysqlconf.cnf`)
```bash
$ find /etc/mysql/|grep dump
/etc/mysql/conf.d/mysqldump.cnf # not mentioned in documentation as well as rename of files
```

### Install 10.2 from mariadb.org
- I don't want tar file with source code, but `.deb` files
- One solution go to the https://mirror.mariadb.org/repo/10.2/ubuntu/pool/main/m/mariadb-10.2/ and `curl` what needed
- Second solution should be to setup repository
```bash
$ cat /etc/apt/sources.list.d/mariadb.list 
deb https://mirror.mariadb.org/repo/10.2/ubuntu bionic main
$ sudo apt update
Get:4 https://ftp.bme.hu/pub/mirrors/mariadb/mariadb-10.2.43/repo/ubuntu bionic InRelease [7722 B]
Get:17 https://ftp.bme.hu/pub/mirrors/mariadb/mariadb-10.2.43/repo/ubuntu bionic/main amd64 Packages [14,9 kB]
Get:18 https://ftp.bme.hu/pub/mirrors/mariadb/mariadb-10.2.43/repo/ubuntu bionic/main i386 Packages [2572 B]
```
- Search package (why unknown for mariadb.org?)
```bash
$ sudo apt search mariadb-server
Sorting... Done
Full Text Search... Done
mariadb-server/unknown,unknown,unknown 1:10.4.24+maria~bionic all
  MariaDB database server (metapackage depending on the latest version)

mariadb-server-10.1/bionic-updates,bionic-security 1:10.1.48-0ubuntu0.18.04.1 amd64
  MariaDB database server binaries

mariadb-server-10.2/unknown 1:10.2.43+maria~bionic amd64
  MariaDB database server binaries

mariadb-server-10.4/unknown 1:10.4.24+maria~bionic arm64
  MariaDB database server binaries

mariadb-server-core-10.1/bionic-updates,bionic-security 1:10.1.48-0ubuntu0.18.04.1 amd64
  MariaDB database core server files

mariadb-server-core-10.2/unknown 1:10.2.43+maria~bionic amd64
  MariaDB database core server files

mariadb-server-core-10.4/unknown 1:10.4.24+maria~bionic arm64
  MariaDB database core server files
```
- Download it (do I need to do that?)
```bash
$ apt download mariadb-server-10.2 # echo $? = 0
```
#### Install `10.2` :
- Install it:
```bash
$ sudo apt install mariadb-server-10.2
Čitam spiskove paketa... Done
Gradim stablo zavisnosti       
Reading state information... Done
The following additional packages will be installed:
  galera-3 libdbd-mysql-perl libdbi-perl libterm-readkey-perl mariadb-client-10.2 mariadb-client-core-10.2 mariadb-server-core-10.2 socat
```
- Set root password
- Unable to set root password
```bash
 │ Unable to set password for the MariaDB "root" user                                                                                     │ 
  │                                                                                                                                        │ 
  │ An error occurred while setting the password for the MariaDB administrative user. This may have happened because the account already   │ 
  │ has a password, or because of a communication problem with the MariaDB server.                                                         │ 
  │                                                                                                                                        │ 
  │ You should check the account's password after the package installation.                                                                │ 
  │                                                                                                                                        │ 
  │ Please read the /usr/share/doc/mariadb-server-10.2/README.Debian file for more information.  
```
Segfault:
```bash
Working directory at /home/anel/builds/data-10.5
....
```
Seems it read all from `~/.my.cnf` that is based on 10.5 although exists `/etc`
```bash
$ cat ~/.my.cnf
[mariadb]
datadir=/home/anel/builds/data-10.5
lc_messages_dir=/home/anel/mariadb/builds/10.5/sql/share
plugin_load_add=ha_connect.so
plugin_dir=/home/anel/mariadb/builds/10.5/storage/connect

$ cat /etc/mysql/
conf.d/          debian-start     mariadb.conf.d/  my.cnf.dpkg-new
debian.cnf       mariadb.cnf      my.cnf           my.cnf.fallback
```
- Run again and search
```bash
$ sudo apt search mariadb|grep "\-10.2"

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

mariadb-backup-10.2/unknown 1:10.2.43+maria~bionic amd64
mariadb-client-10.2/unknown,now 1:10.2.43+maria~bionic amd64 [installed,automatic]
mariadb-client-core-10.2/unknown,now 1:10.2.43+maria~bionic amd64 [installed,automatic]
mariadb-server-10.2/unknown,now 1:10.2.43+maria~bionic amd64 [installed]
mariadb-server-core-10.2/unknown,now 1:10.2.43+maria~bionic amd64 [installed,automatic]
```
- WHen removed
```bash
$ sudo apt search mariadb|grep "\-10.2"

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

mariadb-backup-10.2/unknown 1:10.2.43+maria~bionic amd64
mariadb-client-10.2/unknown,now 1:10.2.43+maria~bionic amd64 [installed,auto-removable]
mariadb-client-core-10.2/unknown,now 1:10.2.43+maria~bionic amd64 [installed,auto-removable]
mariadb-server-10.2/unknown,now 1:10.2.43+maria~bionic amd64 [residual-config]
mariadb-server-core-10.2/unknown,now 1:10.2.43+maria~bionic amd64 [installed,auto-removable]
```
- When `auto-removed`
```bash
$ sudo apt autoremove mariadb-server-10.2
Removing mariadb-client-10.2 (1:10.2.43+maria~bionic) ...
Removing mariadb-client-core-10.2 (1:10.2.43+maria~bionic) ...
Removing mariadb-server-core-10.2 (1:10.2.43+maria~bionic) ...
dpkg: upozorenje: while removing mariadb-server-core-10.2, directory '/usr/share/mysql' not empty so not removed

$ sudo apt search mariadb|grep "\-10.2"

mariadb-backup-10.2/unknown 1:10.2.43+maria~bionic amd64
mariadb-client-10.2/unknown,now 1:10.2.43+maria~bionic amd64 [residual-config]
mariadb-client-core-10.2/unknown 1:10.2.43+maria~bionic amd64
mariadb-server-10.2/unknown,now 1:10.2.43+maria~bionic amd64 [residual-config]
mariadb-server-core-10.2/unknown 1:10.2.43+maria~bionic amd64
```
- Note needed `sudo apt purge mariadb-client-10.2`
- When started 10.2 with pre-existing docker mysqld container it can install and run in parallel (mysqld 10.2.43)
#### Install 10.3 version with patch `pgrep`
- It will remove 10.2
```bash
$ cat /etc/apt/sources.list.d/mariadb.list 
deb https://mirror.mariadb.org/repo/10.2/ubuntu bionic main
deb https://mirror.mariadb.org/repo/10.3/ubuntu bionic main
$ sudo apt update

$ sudo apt install mariadb-server-10.3
  mariadb-client-10.3 mariadb-client-core-10.3 mariadb-server-core-10.3
Predloženi paketi:
  mariadb-test tinyca
Slijedeći paketi će biti UKLONJENI:
  mariadb-client-10.2 mariadb-client-core-10.2 mariadb-server-10.2 mariadb-server-core-10.2
Slijedeći NOVI paketi će biti instalirani:
  mariadb-client-10.3 mariadb-client-core-10.3 mariadb-server-10.3 mariadb-server-core-10.3

```
- Note:there is no `pgrep` in `postrm` so no stop of server with specific namespace,however this should raise an bug and it didn't.
  `sudo mysqladmin ping`  is called and `mysqld is alive` is obtained (without knowledge about the port used)
- Note again: `dpkg: upozorenje: while removing mariadb-server-core-10.2, directory '/usr/share/mysql' not empty so not removed`
#### Purge 10.3
- Purge 10.3 
```bash
$ sudo apt purge mariadb-server-10.3

$ sudo apt search mariadb|grep 10.3

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

mariadb-client-10.3/unknown,now 1:10.3.34+maria~bionic amd64 [installed,auto-removable]
mariadb-client-core-10.3/unknown,now 1:10.3.34+maria~bionic amd64 [installed,auto-removable]
mariadb-server-10.3/unknown 1:10.3.34+maria~bionic amd64
mariadb-server-core-10.3/unknown,now 1:10.3.34+maria~bionic amd64 [installed,auto-removable]
```
- Auto-remove the same package
```bash
$ sudo apt auto-remove mariadb-server-10.3
$ sudo apt search mariadb|grep 10.3

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

mariadb-client-10.3/unknown,now 1:10.3.34+maria~bionic amd64 [residual-config]
mariadb-client-core-10.3/unknown 1:10.3.34+maria~bionic amd64
mariadb-server-10.3/unknown 1:10.3.34+maria~bionic amd64
mariadb-server-core-10.3/unknown 1:10.3.34+maria~bionic amd64
```
- Again need manually to *purge* mariadb-client-10.3
- Note that some downloads are not presetn 10.2.39 (there is a documentation that is not appeared in download)
  and 10.2.42 (no link that is removed from download)
- However old repositories can be found on archive.mariadb.org
#### 
#### Install version prior patch with `pgrep`
- Commit is already in 10.2.43, and before
```bash
$ git tag --contains fb7c1b9415c9
mariadb-10.2.32
mariadb-10.2.33
```
Now we need to go to that installation and verify (mirror.mariadb.org has last 3(? not strong policy about) releases.
- One can use `archive` https://archive.mariadb.org/repo/10.2.31/ (not possible with apt,no format math ?)
  GOt some weird results?
```bash
$ sudo echo "deb https://archive.mariadb.org/repo/10.2.31/ubuntu bionic main" >>/etc/apt/sources.list.d/mariadb.list
$ sudo apt update
Get:12 https://archive.mariadb.org/repo/10.2.31/ubuntu bionic InRelease [7716 B]
Get:14 https://archive.mariadb.org/repo/10.2.31/ubuntu bionic/main i386 Packages [2575 B]
Get:15 https://archive.mariadb.org/repo/10.2.31/ubuntu bionic/main amd64 Packages [14,0 kB]
```
##### Working with deb files
- Let's try with `wget`
```bash
$ wget https://archive.mariadb.org/repo/10.2.31/ubuntu/pool/main/m/mariadb-10.2/mariadb-server-10.2_10.2.31%2Bmaria~bionic_amd64.deb
```
- Inspect files (`dpkg-deb --help`)
```bash
# -c content, used in autobake `grep -F 'dpkg-deb` debian/*`
$ dpkg -c <.deb>
# -I information
$ dpkg - I <.deb>
# -f fields of main 'control' file
$ dpkg-deb -f mariadb-server-10.2_10.2.31+maria~bionic_amd64.deb Provides #Depends, Replaces, etc.
default-mysql-server, virtual-mysql-server
# Extract data with `ar`
$ ar -x mariadb-server-10.2_10.2.31+maria~bionic_amd64.deb
# debian-binary - version string of a package
# control.tar.gz - control files - 
# data.tar.gz    - program data (all dadta in /usr directory after extracting witih `tar`)
$ ls 
control.tar.xz  debian-binary
data.tar.xz     mariadb-server-10.2_10.2.31+maria~bionic_amd64.deb
# Alternatively `dpkg-deb -x` (extract without install)
# TO extract control section is to use `dpkg -e`, got
$ ls DEBIAN/
conffiles  control  postinst  preinst  templates
config     md5sums  postrm    prerm    triggers
# For the remote directories use `apt-file`
$ sudo apt-file update
$ apt-file list mariadb # nothing
```
- Install deb file
```bash
$ sudo dpkg -i <deb>
```
- Warning
```
 │ The old data directory will be saved at new location                      │ 
 │                                                                           │ 
 │ A file named /var/lib/mysql/debian-*.flag exists on this system. The      │ 
 │ number indicates a database binary format version that cannot             │ 
 │ automatically be upgraded (or downgraded).                                │ 
 │                                                                           │ 
 │ Therefore the previous data directory will be renamed to                  │ 
 │ /var/lib/mysql-* and a new data directory will be initialized at          │ 
 │ /var/lib/mysql.                                                           │ 
 │                                                                           │ 
 │ Please manually export/import your data (e.g. with mysqldump) if needed.
```
^^^ Don't want to add other deb files as dependencies
- Note apt will use only the latest version, see below
```bash
$ cat /etc/apt/sources.list.d/mariadb.list 
#deb https://mirror.mariadb.org/repo/10.2/ubuntu bionic main
deb https://mirror.mariadb.org/repo/10.3/ubuntu bionic main
deb https://archive.mariadb.org/repo/10.2.31/ubuntu bionic main
```
After that `apt search mariadb|grep 10.2` will have `10.2.31` only.

- One can use ubuntu `archive` from ubuntu http://archive.ubuntu.com/ubuntu/
```bash
$ sudo echo deb-src http://archive.ubuntu.com/ubuntu/ bionic universe >>/etc/apt/sources.list
```
#### Testing MDEV
- For single container I couldn't proof
- FOr 50 containers
```bash
$ for i in `seq 50`; do docker container run --name "mysql-$i" --rm -e MYSQL_ROOT_PASSWORD=secret -d mysql; done
616c1a9f4262f2d5f1e8d9ba8b91169afd37c48f56269b3d1a89707ed3ca8451
f8c8de0368b69e81a0ea6cb5e16188042bcf12049821f2f854a627c4cc7c8d50
0fc05930e90e5b9c7fb529dfd66b98daf64ac1e83ca8da8dada2d86e21c4ab72
a60b335e6d4f529bd94468d5f69746b75f0e14ced808091adea585642d245a90
4369ff46ab7cabd1cfaba0af2a27a25332bed8c867861e1b4b09ef9fe3442ede
c7a3f786c9c1864df3f41c83c72d76322e6f24fe2e86e5302ccc738a278674f3
78f124dbd0a292c61800576cf829700aff6b485b8c7b89f2f8bdfef2a1101220
dfd8ff55219a7133aa8e3a9b9f536ba121b4be41508374e2c864f4be854baf2e
151ab2ab09f19009a60f0b3a91d114bb404c8dda61b066059ce3a1b03372d9df
e5d5afaa056bc5da757194444412d1744c1c2f8e5ea44171b9d6c0131a189022
3b7afd69320de8c475c9cb95e9a5bfb2068c37900647c32c83b70db28f47a37e
9568932a2fdc989e742f1c7c18a73a929609dc03d4d85b9bfeb47fd5cb9e949b
b843f5dca5e47a0ee8076f981b0f29c6c33fd2b16e5c4f3b8bcdff425725754f
3bfa3304fb4f51e136549a4d1c66a36e62c050c60e94c860fa00494787dab275
9891d675e63d3ed4170a2881ef73b92c1bab0ba5b4808fd0e0178540dc2c6814
abe3e771db136ece1c7d0ef7b13a1f86a1aebaa18800b12346d3ad7cd7fb0cb9
17b7f4d7257e99c859ef020ed32945dc9097114b1440ee75fef34604ff6e00d6
1981714d182a566636f283cb1002056cf38fd2c1202af565f1afd5ef53467ce5
2e2b5162e434b574039b4bb0fbba809f547fe8a062e5fc64cd22c0c97ac07bf1
06eedf319b877715fbcaf5bfdafe1bc4e448a23095643213dbae7fce8c7650ac
72e571a3eb59951540c7080217b0686fa379761d79c7a238592106f1444307f3
92a903e3e2eafa5b91b4f3c00f1f4bb4afc176af24e03f8d9254119ce9bfff72
7d478097b5bff6e5e860e04a2e4d0b01bc82a24ca7f172043c1762aa7ce9fc45
34e2b62f46e360c426d1f18382134bc6da3907820f2e33b5114afef51699bbd8
8728ae545ef918b26288d20fea74a329c18c058c819493e8c77cd4ca12980313
998056a2198312c7efb45804569bfb25265af793132381ad1047410308ae2af2
945b7f96bc4db617567846afc53285e2da825574abc9b70f16488ab9c1c08ec1
52887790f862326148320c7bb6b4a2137c38022bb59feb9b20226188a8af05c6
f9f4d4d1f9a4ee71a846f8e48a2c3b7edf12fa91fdaf38a193b7cbc0620c414e
e951b07b1c7212b4a88e02030a5b5b1ad45fe491ece74f8effe3d0c90545fedd
a5077ed734cf3959ebcc7de06698b2b5fc8a2e0e55a520bf874c45385f539380
35265b708ff9e18a26ea50d1be31165f0da05e0fcf65e69a78618079567763b0
feb69d5ec7711fcdb4bb37ee0ae60afc97a7783986d141e6f5753ded2f72beac
1c6734d182a825b676d68b6be74f8026ab4977627d2575c9923ae2d1b7959691
78c885c91032a81f66447bf7bcb61e80339ebd5c289540c28c2dcfac33ff0c43
50c0199b342f5822249c5b160ef828ba4e6ca15999cd17360ba0687cc9099724
01c3680ce0ad7ec339edd32a0d8324a7c3f652c121d1f686f007f97602e7a021
23f966ef989dde4e4400add75b2a26e981a0e0da740d6d1f6876a8f2bd95db2a
6e2ca36cb5ba9fa023be1f2fd3c53bca8ad4125bab2e6d1003b4029e66b339c1
6ec8a27c0cd7960190e67016d19ee3489cee846343fc843d8466d776756fa39a
4e6132674d5b1f3e2cd3095bc058d22822d6698c529bb777814a03089f62e776
eeb8df1e83c04937c4d8a8a924e45eacf8b609216b0ba9a0710abc2324998fa5
43c4218b89bc84ea845aaaa5b81b49e357782f0bea4bd8b30524963dabd79e57
45a61c7f66ac6dfc1747c47b9ae7cc3142600cf5c59697aa0cca9012d95057a4
e1f404dba782747d166589b07f2bb28619ea023c51358681c6f2eed824d8e157
c02328b2dfe210f84f64b389bc60e699e880463452d407b0a6a2767c76e9e4a3
0c48112cd8f36c76af8f8ad977af15f70bba686d753567a9fec173da6eac58a2
0e34bc330110443b119b896d22be30486a75b431f3f66cebb82efd6f8b49a2a5
8257bd14f5cec917d3aa154ea539f76a6020b09487524641a2630b5aad7a0d95
e5ce6230d83c58e9602ef44e9befd60de4fc35672aa7b4e32f9e7b8b224b91fa

$ sudo apt install mariadb-server-10.2 # still no error for MDEV-21331
```
* CONCLUSION: IT DOESN'T WORK WITH BIONIC
- Testing with Debian 11 (https://www.debian.org/releases/buster/debian-installer/)
  Download the `SHA256SUMS` file and test integrity of downloaded iso file
  ```bash
  $ sha256sum --ignore-missing -c SHA256SUMS.txt 
debian-11.3.0-amd64-DVD-1.iso: OK
  ```


