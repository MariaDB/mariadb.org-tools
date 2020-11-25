## This document contains some tips for building MariaDB from source on OpenBSD

This document is based on my experience building MariaDB 10.6 on OpenBSD 6.8.  
Some things might be slightly different for different version of OpenBSD or MariaDB.

### Setting up an OpenBSD VM with VMWare
- Download the .iso image from openbsd.org
- Create a new VM in VMWare and select the downloded ISO 
- VMWare will guess the ISO is a Debian linux, choose `Other`, then `FreeBSD`, should be close enough
- Start the new VM

### Installation process
- Installation happens via command line, don't panic.
- Remember we are trying to quickly reproduce some MariaDB bug, so we want to get to a usable shell as fast as possible
- When prompted if you choose to `(I)nstall, (A)utoInstall, ...`, type `I(nstall)`.
- Hit `ENTER`, default, for most/all keyboard/networking settings you're asked for 
  (choose dhcp when possible)
- At some point you'll be asked where to install OpenBSD. `?` reveals all detected hard drives.
  The correct one for me was `sd0`. In the `?` menu, I observed `sd0(20GB)` and I knew I created a VM disk file of 20GB.
- Choose `Auto` for partitioning, I'm pretty sure we don't care how OpenBSD creates the partitions.
- When asked about `sets` (these are apparently the openbsd programs to be installed).
  Type `all` to choose all of them and when the next prompt opens, choose `done`.
- When asked about sets location, `http` should be simpler, but it didn't work for me.
  So choose the drive (`sd0` for me) that installer displays as default.
- `Directory does not contain SHA256.sig. Continue without verification? [no]`  
  Type `yes`
- When installation is done and you reboot, run a `ping 8.8.8.8`. If you didn't choose `dhcp` like I suggested
above, ping won't work.
- To fix the lack of internet:  
 Run `ifconfig` and find the right network interface and then run `dhclient` on it.  
 For me it was: `dhclient em0`.  
 Ping should work now and so installing packages.

### Prerequisites
You will need to install the following packages before building: 
- Run `pkg_add git jsoncpp cmake bison`


 After prerequisites are installed, MariaDB can be cloned and built using the regular `git, cmake, make` commands.
