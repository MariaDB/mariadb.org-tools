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
#set -ex
set -e
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

# set location of prep.conf and prep.log to XDG-compatible directories and then
# create them if they don't exist
dir_conf=${XDG_CONFIG_HOME:-~/.config}
dir_log=${XDG_DATA_HOME:-~/.local/share}


# Set the appropriate dists based on the ${ARCHDIR} of the packages
case ${ARCHDIR} in
  *"5.5"*)
    ubuntu_dists="trusty"
    ;;
  *"10.0"*)
    ubuntu_dists="trusty xenial"
    ;;
  *)
    ubuntu_dists="trusty xenial bionic cosmic"
    ;;
esac

#-------------------------------------------------------------------------------
#  Functions
#-------------------------------------------------------------------------------

line() {
  echo "-------------------------------------------------------------------------------"
}

runCommand() {
  echo "+ ${@}"
  #sleep 1
  if ${@} ; then
    echo
    return 0
  else
    echo
    return 1
  fi
}

loadDefaults() {
  # Load the paths (if they exist)
  if [ -f ${dir_conf}/prep.conf ]; then
      . ${dir_conf}/prep.conf
  else
    echo
    echo "The file ${dir_conf}/prep.conf does not exist in your home."
    echo "The prep script creates a default template of this file when run."
    echo "Exiting..."
    exit 1
  fi
}

#-------------------------------------------------------------------------------
#  Main Script
#-------------------------------------------------------------------------------
# Get the GPG daemon running so we don't have to keep entering the password for
# the GPG key every time we sign a package
eval $(gpg-agent --daemon)

loadDefaults                                    # Load Default paths and vars

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
  ubuntu_dists="trusty xenial"
  suffix="signed-ent"
else
  origin="MariaDB"
  description="MariaDB Repository"
  #gpg_key="package-signing-key@mariadb.org"    # mariadb.org signing key
  gpg_key="0xcbcb082a1bb943db"                  # mariadb.org signing key
  gpg_key_2016="0xF1656F24C74CD1D8"             # 2016-03-30 mariadb.org signing key
  #gpg_key="0xcbcb082a1bb943db 0xF1656F24C74CD1D8" # both keys
  suffix="signed"
fi

if [ ! -d ${REPONAME} ]; then
  mkdir "$REPONAME"
fi

cd "$REPONAME"

if [ ! -d conf ]; then
  mkdir conf
fi

# Add packages
for dist in ${ubuntu_dists}; do
  echo
  line
  echo + ${dist}
  line

  # First we import the amd64 files
  case ${dist} in 
    'trusty'|'xenial'|'cosmic')
      runCommand reprepro --basedir=. include ${dist} $ARCHDIR/kvm-deb-${dist}-amd64/debs/binary/mariadb-*_amd64.changes
      ;;
    'bionic')
      # Need to remove *.buildinfo lines from changes file so reprepro doesn't choke
      #runCommand sudo vi $ARCHDIR/kvm-deb-${dist}-amd64/debs/binary/mariadb-*_amd64.changes
      runCommand reprepro --basedir=. include ${dist} $ARCHDIR/kvm-deb-${dist}-amd64/debs/binary/mariadb-*_amd64.changes
      # Need to include .deb files manually because of https://bugs.launchpad.net/ubuntu/+source/reprepro/+bug/799889
      #for file in $(find "$ARCHDIR/kvm-deb-${dist}-amd64/" -name '*.deb'); do runCommand reprepro --basedir=. includedeb ${dist} ${file} ; done
      #for file in $(find "$ARCHDIR/kvm-deb-${dist}-amd64/" -name '*.dsc'); do runCommand reprepro --basedir=. includedsc ${dist} ${file} ; done
      ;;
    * )
      for file in $(find "$ARCHDIR/kvm-deb-${dist}-amd64/" -name '*.deb'); do runCommand reprepro --basedir=. includedeb ${dist} ${file} ; done
      for file in $(find "$ARCHDIR/kvm-deb-${dist}-amd64/" -name '*.dsc'); do runCommand reprepro --basedir=. includedsc ${dist} ${file} ; done
      ;;
  esac

  # Include i386 debs
  case ${dist} in
    'trusty'|'xenial')
      for file in $(find "$ARCHDIR/kvm-deb-${dist}-x86/" -name '*_i386.deb'); do runCommand reprepro --basedir=. includedeb ${dist} ${file} ; done
      ;;
  esac

  # Include ppc64le debs
  case ${dist} in
    'trusty')
      for file in $(find "$ARCHDIR/kvm-deb-${dist}-ppc64le/" -name '*_ppc64el.deb'); do runCommand reprepro --basedir=. includedeb ${dist} ${file} ; done
      for file in $(find "${dir_at}/${dist}-ppc64el-${suffix}/" -name '*_ppc64el.deb'); do runCommand reprepro --basedir=. includedeb ${dist} ${file} ; done
      ;;
    'xenial'|'bionic')
      for file in $(find "$ARCHDIR/kvm-deb-${dist}-ppc64le/" -name '*_ppc64el.deb'); do runCommand reprepro --basedir=. includedeb ${dist} ${file} ; done
      ;;
  esac


  # Include aarch64 debs
  case ${dist} in
    'xenial'|'bionic')
      for file in $(find "$ARCHDIR/kvm-deb-${dist}-aarch64/" -name '*_arm64.deb'); do runCommand reprepro --basedir=. includedeb ${dist} ${file} ; done
      ;;
  esac

  # Add in custom jemalloc packages for distros that need them
  case ${dist} in
    "lucid")
      for file in $(find "${dir_jemalloc}/${dist}-amd64/" -name '*_amd64.deb'); do runCommand reprepro --basedir=. includedeb ${dist} ${file} ; done
      if [ "${ENTERPRISE}" != "yes" ]; then
        for file in $(find "${dir_jemalloc}/${dist}-i386/" -name '*_i386.deb'); do runCommand reprepro --basedir=. includedeb ${dist} ${file} ; done
      fi
      ;;
    "precise")
      for file in $(find "${dir_jemalloc}/${dist}-amd64/" -name '*_amd64.deb'); do runCommand reprepro --basedir=. includedeb ${dist} ${file} ; done
      if [ "${ENTERPRISE}" != "yes" ]; then
        for file in $(find "${dir_jemalloc}/${dist}-i386/" -name '*_i386.deb'); do runCommand reprepro --basedir=. includedeb ${dist} ${file} ; done
      fi
      ;;
    "quantal")
      for file in $(find "${dir_jemalloc}/${dist}-amd64/" -name '*_amd64.deb'); do runCommand reprepro --basedir=. includedeb ${dist} ${file} ; done
      if [ "${ENTERPRISE}" != "yes" ]; then
        for file in $(find "${dir_jemalloc}/${dist}-i386/" -name '*_i386.deb'); do runCommand reprepro --basedir=. includedeb ${dist} ${file} ; done
      fi
      ;;
  esac


  # Add in custom libjudy packages for distros that need them
  case ${dist} in
    "trusty")
      runCommand reprepro --basedir=. includedeb ${dist} ${dir_judy}/libjudydebian1_1.0.5-4_ppc64el.deb
      ;;
  esac


  # Copy in galera packages if requested
  if [ ${GALERA} = "yes" ]; then
    case ${ARCHDIR} in
      *10.4*)
        ver_galera_real=${ver_galera4}
        galera_name='galera-4'
        ;;
      *)
        ver_galera_real=${ver_galera}
        galera_name='galera-3'
        ;;
    esac
    for gv in ${ver_galera_real}; do
      if [ "${ENTERPRISE}" = "yes" ]; then
        #for file in $(find "${dir_galera}/galera-${gv}-${suffix}/" -name "*${dist}*amd64.deb"); do reprepro -S optional -P misc --basedir=. includedeb ${dist} ${file} ; done
        runCommand reprepro --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/${galera_name}_${gv}-${dist}*_amd64.changes
        if [ "${dist}" = "trusty" ] || [ "${dist}" = "xenial" ]; then
          runCommand reprepro --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/${galera_name}_${gv}-${dist}*_ppc64el.changes
        fi
      else

        #for file in $(find "${dir_galera}/galera-${gv}-${suffix}/" -name "*${dist}*.deb"); do reprepro -S optional -P misc --basedir=. includedeb ${dist} ${file} ; done

        # include amd64
        runCommand reprepro --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/${galera_name}_${gv}-${dist}*_amd64.changes

        # include i386
        case ${dist} in
          'trusty'|'xenial')
            runCommand reprepro --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/${galera_name}_${gv}-${dist}*_i386.changes
            ;;
        esac

        # include ppc64le
        case ${dist} in
          'trusty'|'xenial'|'bionic')
            runCommand reprepro --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/${galera_name}_${gv}-${dist}*_ppc64el.changes
            ;;
        esac

        # include arm64 (aarch64)
        case ${dist} in
          'xenial'|'bionic')
            runCommand reprepro --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/${galera_name}_${gv}-${dist}*_arm64.changes
            ;;
        esac
      fi
    done
  fi
done

# Create sums of .deb packages
echo "+ md5sum ./pool/main/*/*/*.deb >> md5sums.txt"
        md5sum ./pool/main/*/*/*.deb >> md5sums.txt
echo "+ sha1sum ./pool/main/*/*/*.deb >> sha1sums.txt"
        sha1sum ./pool/main/*/*/*.deb >> sha1sums.txt
echo "+ sha256sum ./pool/main/*/*/*.deb >> sha256sums.txt"
        sha256sum ./pool/main/*/*/*.deb >> sha256sums.txt
echo "+ sha512sum ./pool/main/*/*/*.deb >> sha512sums.txt"
        sha512sum ./pool/main/*/*/*.deb >> sha512sums.txt

