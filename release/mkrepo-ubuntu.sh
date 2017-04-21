#!/bin/bash - 
#===============================================================================
#
#          FILE:  mkrepo-ubuntu.sh
# 
#         USAGE:  $0 <galera_pkgs?> <enterprise?> <reponame> <archive_dir>
# 
#   DESCRIPTION:  A script to generate the Ubuntu repositories for MariaDB
#                 Ubuntu packages.
#
#                 The script copies files from the archive directory into
#                 separate directories for each distribution/cpu combination
#                 (just like they are stored in the archive directory). For
#                 best results, it should be run within an empty directory.
#
#                 After running the script, the directories are uploaded to the
#                 mirrors, replacing the previous version in that series (i.e.
#                 the 10.0.15 files are replaced by the 10.0.16 files and the
#                 10.1.1 files are replaced by the 10.1.2 files, and so on).
# 
#===============================================================================

umask 002

#killall gpg-agent
# Right off the bat we want to log everything we're doing and exit immediately
# if there's an error
set -ex
  # -e  Exit immediately if a simple command exits with a non-zero status,
  #     unless the command that fails is part of an until or  while loop, part
  #     of an if statement, part of a && or || list, or if the command's return
  #     status is being inverted using !.  -o errexit
  #
  # -x  Print a trace of simple commands and their arguments after they are
  #     expanded and before they are executed.

#-------------------------------------------------------------------------------
#  Set command-line options
#-------------------------------------------------------------------------------
GALERA="$1"                       # copy in galera packages? 'yes' or 'no'
ENTERPRISE="$2"                   # is this an enterprise release? 'yes' or 'no'
REPONAME="$3"                     # name of the dir, usually 'ubuntu'
ARCHDIR="$4"                      # path to the packages
P8_ARCHDIR="$5"                   # path to p8 packages (optional)

#-------------------------------------------------------------------------------
#  Variables which are not set dynamically (because they don't change often)
#-------------------------------------------------------------------------------
galera_versions="25.3.19"                          # Version of galera in repos
dir_galera="/ds413/galera"                        # Location of galera pkgs
dir_jemalloc="/ds413/vms-customizations/jemalloc" # Location of jemalloc pkgs
#dir_xtrabackup="/ds413/repo/xtrabackup"           # Location of xtrabackup pkgs
#ver_xtrabackup="2.2.9"                            # Version of xtrabackup
dir_at="/ds413/vms-customizations/advance-toolchain" # Location of at pkgs

# Set the appropriate dists based on the ${ARCHDIR} of the packages
case ${ARCHDIR} in
  *"5.5"*)
    ubuntu_dists="precise trusty"
    ;;
  *"10.0"*)
    ubuntu_dists="precise trusty xenial yakkety"
    ;;
  *)
    ubuntu_dists="precise trusty xenial yakkety zesty"
    ;;
esac

# Standard Architectures
architectures="amd64 i386 source"

#-------------------------------------------------------------------------------
#  Main Script
#-------------------------------------------------------------------------------
# Get the GPG daemon running so we don't have to keep entering the password for
# the GPG key every time we sign a package
eval $(gpg-agent --daemon)

# At this point, all variables should be set. Print a usage message if the
# ${ARCHDIR} variable is not set (the last of the command-line variables).
if [ ! -d "$ARCHDIR" ] ; then
    echo 1>&2 "Usage: $0 <galera_pkgs?> <enterprise?> <reponame> <archive_dir>"
    echo 1>&2 "example: $0 yes no ubuntu /media/backup/archive/pack/10.0/build-1234"
    exit 1
fi

# After this point, we tread unset variables as an error
set -u
  # -u  Treat unset variables as an error when performing parameter expansion.
  #     An error message will be written to the standard error, and a
  #     non-interactive shell will exit.

# If this is an "Enterprise" MariaDB release, sign with the mariadb.com key,
# otherwise, sign with the mariadb.org key
if [ "${ENTERPRISE}" = "yes" ]; then
  origin="MariaDB Enterprise"
  description="MariaDB Enterprise Repository"
  gpg_key="signing-key@mariadb.com"            # new enterprise key (2014-12-18)
  #gpg_key="0xce1a3dd5e3c94f49"                # new enterprise key (2014-12-18)
  #ubuntu_dists="precise trusty utopic"
  ubuntu_dists="precise trusty xenial"                # no utopic for enterprise just yet 
  architectures="amd64 i386 source"                  # for enterprise, add i386
  architectures_ppc64el="amd64 i386 ppc64el source"   # for trusty and xenial, add ppc64el
  suffix="signed-ent"
else
  origin="MariaDB"
  description="MariaDB Repository"
  #gpg_key="package-signing-key@mariadb.org"    # mariadb.org signing key
  gpg_key="0xcbcb082a1bb943db"                  # mariadb.org signing key
  gpg_key_2016="0xF1656F24C74CD1D8"             # 2016-03-30 mariadb.org signing key
  #gpg_key="0xcbcb082a1bb943db 0xF1656F24C74CD1D8" # both keys
  #architectures_ppc64el="${architectures}"       # same if not enterprise
  architectures_ppc64el="amd64 i386 ppc64el source"   # for trusty and xenial, add ppc64el
  suffix="signed"
fi

if [ ! -d ${REPONAME} ]; then
  mkdir "$REPONAME"
fi

cd "$REPONAME"

if [ ! -d conf ]; then
  mkdir conf
fi

# Delete the conf/distributions file if it exists
#if [ -f conf/distributions ]; then
#  rm -f "conf/distributions"
#fi

# Removing conf/distributions file creation step - 2016-09-12
## Create the conf/distributions file
#for dist in ${ubuntu_dists}; do
#  case ${dist} in 
#    'trusty') cat >>conf/distributions <<END
#Origin: ${origin}
#Label: MariaDB
#Codename: trusty
#Architectures: ${architectures_ppc64el}
#Components: main
#Description: ${description}
#SignWith: ${gpg_key}
#
#END
#      ;;
#    'xenial') cat >>conf/distributions <<END
#Origin: ${origin}
#Label: MariaDB
#Codename: ${dist}
#Architectures: ${architectures_ppc64el}
#Components: main
#Description: ${description}
#SignWith: ${gpg_key_2016}
#
#END
#      ;;
#    *) cat >>conf/distributions <<END
#Origin: ${origin}
#Label: MariaDB
#Codename: ${dist}
#Architectures: ${architectures}
#Components: main
#Description: ${description}
#SignWith: ${gpg_key}
#
#END
#      ;;
#  esac
#done

# Remove packages from deprecated distros (if they are present)
#reprepro --basedir=. --delete clearvanished

# Add packages
for dist in ${ubuntu_dists}; do
  echo ${dist}
  case ${dist} in 
    'trusty'|'utopic'|'xenial'|'yakkety'|'zesty')
      reprepro --basedir=. include ${dist} $ARCHDIR/kvm-deb-${dist}-amd64/debs/binary/mariadb-*_amd64.changes
      ;;
    * )
      for file in $(find "$ARCHDIR/kvm-deb-${dist}-amd64/" -name '*.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      for file in $(find "$ARCHDIR/kvm-deb-${dist}-amd64/" -name '*.dsc'); do reprepro --basedir=. includedsc ${dist} ${file} ; done
      ;;
  esac

  if [ "${ENTERPRISE}" != "yes" ]; then
    for file in $(find "$ARCHDIR/kvm-deb-${dist}-x86/" -name '*_i386.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
  fi

  # Include trusty ppc64le debs
  if [ "${dist}" = "trusty" ]; then
    for file in $(find "$ARCHDIR/kvm-deb-${dist}-ppc64le/" -name '*_ppc64el.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
    for file in $(find "${dir_at}/${dist}-ppc64el-${suffix}/" -name '*_ppc64el.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
  fi

  # Include xenial ppc64le debs
  if [ "${dist}" = "xenial" ]; then
    for file in $(find "$ARCHDIR/kvm-deb-${dist}-ppc64le/" -name '*_ppc64el.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
  fi

  #if [ "${ENTERPRISE}" = "yes" ]; then
    #if [ "${dist}" = "xenial" ]; then
    #  if [ ! -d "${P8_ARCHDIR}" ] ; then
    #    echo 1>&2 "! I can't find the directory for Power 8 debs! '${P8_ARCHDIR}'"
    #    exit 1
    #  else
    #    for file in $(find "${P8_ARCHDIR}/p8-${dist}-deb/" -name '*_ppc64el.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
    #    # Add xtrabackup files
    #    #reprepro --basedir=. include ${dist} ${dir_xtrabackup}/ppc64el/${ver_xtrabackup}-${suffix}/${dist}/percona-xtrabackup_${ver_xtrabackup}*_ppc64el.changes
    #  fi
    #fi
  #fi

  # Add in custom jemalloc packages for distros that need them
  case ${dist} in
    "lucid")
      for file in $(find "${dir_jemalloc}/${dist}-amd64/" -name '*_amd64.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      if [ "${ENTERPRISE}" != "yes" ]; then
        for file in $(find "${dir_jemalloc}/${dist}-i386/" -name '*_i386.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      fi
      ;;
    "precise")
      for file in $(find "${dir_jemalloc}/${dist}-amd64/" -name '*_amd64.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      if [ "${ENTERPRISE}" != "yes" ]; then
        for file in $(find "${dir_jemalloc}/${dist}-i386/" -name '*_i386.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      fi
      ;;
    "quantal")
      for file in $(find "${dir_jemalloc}/${dist}-amd64/" -name '*_amd64.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      if [ "${ENTERPRISE}" != "yes" ]; then
        for file in $(find "${dir_jemalloc}/${dist}-i386/" -name '*_i386.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      fi
      ;;
    * )
      echo "no custom jemalloc packages for ${dist}"
      ;;
  esac





  # Copy in galera packages if requested
  if [ ${GALERA} = "yes" ]; then
    for gv in ${galera_versions}; do
      if [ "${ENTERPRISE}" = "yes" ]; then
        #for file in $(find "${dir_galera}/galera-${gv}-${suffix}/" -name "*${dist}*amd64.deb"); do reprepro -S optional -P misc --basedir=. includedeb ${dist} ${file} ; done
        reprepro --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/galera-3_${gv}-${dist}*_amd64.changes
        if [ "${dist}" = "trusty" ] || [ "${dist}" = "xenial" ]; then
          reprepro --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/galera-3_${gv}-${dist}*_ppc64el.changes
        fi
      else
        #for file in $(find "${dir_galera}/galera-${gv}-${suffix}/" -name "*${dist}*.deb"); do reprepro -S optional -P misc --basedir=. includedeb ${dist} ${file} ; done
        reprepro --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/galera-3_${gv}-${dist}*_amd64.changes
        reprepro --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/galera-3_${gv}-${dist}*_i386.changes
        if [ "${dist}" = "trusty" ] || [ "${dist}" = "xenial" ]; then
          reprepro --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/galera-3_${gv}-${dist}*_ppc64el.changes
        fi
      fi
    done
  fi
done

# Create sums of .deb packages
md5sum ./pool/main/*/*/*.deb >> md5sums.txt
sha1sum ./pool/main/*/*/*.deb >> sha1sums.txt
sha256sum ./pool/main/*/*/*.deb >> sha256sums.txt
sha512sum ./pool/main/*/*/*.deb >> sha512sums.txt

