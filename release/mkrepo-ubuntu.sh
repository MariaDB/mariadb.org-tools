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

# if the ${ARCHDIR} var has a 'ci' directory in it then we are using a ci
# build, otherwise we are using bb
case ${ARCHDIR} in
  */ci/*) build_type=ci ;;
  *) build_type=bb ;;
esac


#-------------------------------------------------------------------------------
#  Variables which are not set dynamically (because they don't change often)
#-------------------------------------------------------------------------------

# set location of prep.conf and prep.log to XDG-compatible directories and then
# create them if they don't exist
dir_conf=${XDG_CONFIG_HOME:-~/.config}
dir_log=${XDG_DATA_HOME:-~/.local/share}

declare -A builder_dir_ci_amd64=([focal]=ubuntu-2004-deb-autobake [jammy]=ubuntu-2204-deb-autobake [mantic]=ubuntu-2310-deb-autobake [noble]=ubuntu-2404-deb-autobake) 
declare -A builder_dir_bb_amd64=([focal]=kvm-deb-focal-amd64 [jammy]=kvm-deb-jammy-amd64 [mantic]=kvm-deb-mantic-amd64 [noble]=kvm-deb-noble-amd64)

declare -A builder_dir_ci_aarch64=([focal]=aarch64-ubuntu-2004-deb-autobake [jammy]=aarch64-ubuntu-2204-deb-autobake [mantic]=aarch64-ubuntu-2310-deb-autobake [noble]=aarch64-ubuntu-2404-deb-autobake)
declare -A builder_dir_bb_aarch64=([focal]=kvm-deb-focal-aarch64 [jammy]=kvm-deb-jammy-aarch64 [mantic]=kvm-deb-mantic-aarch64 [noble]=kvm-deb-noble-aarch64)

declare -A builder_dir_ci_ppc64le=([focal]=pc9-ubuntu-2004-deb-autobake [jammy]=ubuntu-2204-deb-autobake [noble]=ubuntu-2404-deb-autobake)
declare -A builder_dir_bb_ppc64le=([focal]=kvm-deb-focal-ppc64le [jammy]=kvm-deb-jammy-ppc64le [noble]=kvm-deb-noble-ppc64le)

declare -A builder_dir_ci_s390x=([focal]=s390x-ubuntu-2004-deb-autobake [jammy]=s390x-ubuntu-2204-deb-autobake [noble]=s390x-ubuntu-2404-deb-autobake)
declare -A builder_dir_bb_s390x=([focal]=kvm-deb-focal-s390x [jammy]=kvm-deb-jammy-s390x [noble]=kvm-deb-noble-s390x)

declare -A builder_dir_ci_x86=([focal]=32bit-ubuntu-2004-deb-autobake)
declare -A builder_dir_bb_x86=([focal]=kvm-deb-focal-x86)

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

# Set the appropriate dists based on the ${ARCHDIR} of the packages
case ${ARCHDIR} in
  *10.2*)
    ubuntu_dists=""
    ;;
  *10.3*|*10.4*|*10.5*)
    ubuntu_dists="focal"
    ;;
  *10.6*|*10.7*|*10.8*|*10.9*|*10.10*)
    ubuntu_dists="focal jammy"
    ;;
  *10.11*|*10.12*|*11.0*|*11.1*|*11.2*|*11.4*|*11.5*)
    ubuntu_dists="focal jammy mantic noble"
    ;;
  *)
    line
    echo "+ ARCHDIR=${ARCHDIR}, can't determine dist, giving up"
    line
    exit 5
    ;;
esac


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

  origin="MariaDB"
  description="MariaDB Repository"
  #gpg_key="package-signing-key@mariadb.org"    # mariadb.org signing key
  gpg_key="0xcbcb082a1bb943db"                  # mariadb.org signing key
  gpg_key_2016="0xF1656F24C74CD1D8"             # 2016-03-30 mariadb.org signing key
  #gpg_key="0xcbcb082a1bb943db 0xF1656F24C74CD1D8" # both keys
  suffix="signed"

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

  case ${dist} in
    focal)   dist_alt='ubu2004' ;;
    jammy)   dist_alt='ubu2204' ;;
    mantic)  dist_alt='ubu2310' ;;
    noble)  dist_alt='ubu2404' ;;
  esac

  # First we import the amd64 files
  builder_dir="builder_dir_${build_type}_amd64[${dist}]"
  case ${dist} in 
    'focal'|'jammy'|'mantic'|'noble')
      runCommand reprepro --basedir=. --ignore=wrongsourceversion include ${dist} $(find $ARCHDIR/${!builder_dir}/ -name mariadb*_amd64.changes)
      ;;
  esac

  # Include ppc64le debs
  builder_dir="builder_dir_${build_type}_ppc64le[${dist}]"
  case ${dist} in
    'focal'|'jammy'|'noble')
      for file in $(find "$ARCHDIR/${!builder_dir}/" -name '*_ppc64el.deb'); do runCommand reprepro --basedir=. includedeb ${dist} ${file} ; done
      for file in $(find "$ARCHDIR/${!builder_dir}/" -name '*_ppc64el.ddeb'); do runCommand reprepro --basedir=. includeddeb ${dist} ${file} ; done
      ;;
  esac

  # Include aarch64 debs
  builder_dir="builder_dir_${build_type}_aarch64[${dist}]"
  case ${dist} in
    'focal'|'jammy'|'mantic'|'noble')
      for file in $(find "$ARCHDIR/${!builder_dir}/" -name '*_arm64.deb'); do runCommand reprepro --basedir=. includedeb ${dist} ${file} ; done
      for file in $(find "$ARCHDIR/${!builder_dir}/" -name '*_arm64.ddeb'); do runCommand reprepro --basedir=. includeddeb ${dist} ${file} ; done
      ;;
  esac

  # Include s390x debs
  builder_dir="builder_dir_${build_type}_s390x[${dist}]"
  case ${dist} in
    'focal'|'jammy'|'noble')
      for file in $(find "$ARCHDIR/${!builder_dir}/" -name '*_s390x.deb'); do runCommand reprepro --basedir=. includedeb ${dist} ${file} ; done
      for file in $(find "$ARCHDIR/${!builder_dir}/" -name '*_s390x.ddeb'); do runCommand reprepro --basedir=. includeddeb ${dist} ${file} ; done
      ;;
  esac

  # Copy in galera packages if requested
  if [ ${GALERA} = "yes" ]; then
    case ${ARCHDIR} in
      *10.2*|*10.3*)
        ver_galera_real=${ver_galera}
        galera_name='galera-3'
        dist_filename=${dist}
        ;;
      *)
        ver_galera_real=${ver_galera4}
        galera_name='galera-4'
        dist_filename=${dist_alt}
        ;;
    esac
    for gv in ${ver_galera_real}; do
        # include amd64
        runCommand reprepro --ignore=wrongdistribution --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/${galera_name}_${gv}-${dist_filename}*_amd64.changes

        # include ppc64le
        case ${dist} in
          'focal'|'jammy'|'noble')
            runCommand reprepro --ignore=wrongdistribution --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/${galera_name}_${gv}-${dist_filename}*_ppc64el.changes
            ;;
        esac

        # include arm64 (aarch64)
        case ${dist} in
          'focal'|'jammy'|'mantic'|'noble')
            runCommand reprepro --ignore=wrongdistribution --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/${galera_name}_${gv}-${dist_filename}*_arm64.changes
            ;;
        esac

        # include s390x
        case ${dist} in
          'focal'|'jammy'|'noble')
            runCommand reprepro --ignore=wrongdistribution --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/${galera_name}_*${dist_filename}*_s390x.changes
            ;;
        esac
    done
  fi

  # Copy in CMAPI package
  case ${dist} in
    'focal'|'jammy'|'mantic'|'noble')
      case ${ARCHDIR} in
        *11.1*)
          # should be ${dist}, but currently we use jammy package (Aug 2023)
          runCommand reprepro --basedir=. includedeb ${dist} ${dir_cmapi}/${ver_cmapi}/11.1*/jammy/mariadb-columnstore-cmapi*${ver_cmapi}*amd64.deb
          runCommand reprepro --basedir=. includedeb ${dist} ${dir_cmapi}/${ver_cmapi}/11.1*/jammy/mariadb-columnstore-cmapi*${ver_cmapi}*arm64.deb
          ;;
        *11.2*|*11.3*)
          # should be ${dist}, but currently we use jammy package (Aug 2023)
          runCommand reprepro --basedir=. includedeb ${dist} ${dir_cmapi}/${ver_cmapi}/11.2*/jammy/mariadb-columnstore-cmapi*${ver_cmapi}*amd64.deb
          runCommand reprepro --basedir=. includedeb ${dist} ${dir_cmapi}/${ver_cmapi}/11.2*/jammy/mariadb-columnstore-cmapi*${ver_cmapi}*arm64.deb
          ;;
      esac
      ;;
  esac


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

