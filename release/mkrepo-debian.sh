#!/bin/bash - 
#===============================================================================
#
#          FILE:  mkrepo-debian.sh
# 
#         USAGE:  $0 <galera_pkgs?> <enterprise?> <reponame> <archive_dir>
# 
#   DESCRIPTION:  A script to generate the Debian repositories for MariaDB
#                 Debian packages.
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
TREE="$3"                         # source tree
REPONAME="$4"                     # name of the dir, usually 'debian'
ARCHDIR="$5"                      # path to the packages

# if the ${ARCHDIR} var has a 'ci' directory in it then we are using a ci
# build, otherwise we are using bb
case ${ARCHDIR} in
  */ci/*) build_type=ci ;;
  *) build_type=bb ;;
esac

#-------------------------------------------------------------------------------
#  Variables which are not set dynamically (because they don't change often)
#-------------------------------------------------------------------------------
architectures="amd64 i386 source"

# set location of prep.conf and prep.log to XDG-compatible directories and then
# create them if they don't exist
dir_conf=${XDG_CONFIG_HOME:-~/.config}
dir_log=${XDG_DATA_HOME:-~/.local/share}


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
    echo 1>&2 "Usage: $0 <galera_pkgs?> <enterprise?> <tree> <reponame> <archive_dir>"
    echo 1>&2 "example: $0 yes no 5.5 debian /media/backup/archive/pack/10.0/build-1234"
    exit 1
fi

# After this point, we tread unset variables as an error
set -u
  # -u  Treat unset variables as an error when performing parameter expansion.
  #     An error message will be written to the standard error, and a
  #     non-interactive shell will exit.

# If this is an "Enterprise" MariaDB release, sign with the mariadb.com key,
# otherwise, sign with the mariadb.org key,
if [ "${ENTERPRISE}" = "yes" ]; then
  origin="MariaDB Enterprise"
  description="MariaDB Enterprise Repository"
  gpg_key="signing-key@mariadb.com"            # new enterprise key (2014-12-18)
  #gpg_key="0xce1a3dd5e3c94f49"                # new enterprise key (2014-12-18)
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
  mkdir -v "$REPONAME"
fi

cd "$REPONAME"

if [ ! -d conf ]; then
  mkdir -v conf
fi

# Delete the conf/distributions file if it exists
#if [ -f conf/distributions ]; then
#  rm -f "conf/distributions"
#fi


# Create the conf/distributions file

#case ${TREE} in
#  '5.5'|'5.5e'|'5.5-galera'|'5.5e-galera'|'10.0'|'10.0e'|'10.0-galera'|'10.0e-galera')
#    squeeze="squeeze"
#cat >conf/distributions <<END
#Origin: ${origin}
#Label: MariaDB
#Codename: squeeze
#Architectures: ${architectures}
#Components: main
#Description: ${description}
#SignWith: ${gpg_key}
#END
#  ;;
#  *)
#    squeeze=""
#    ;;
#esac

# removing conf/distributions file creation step - 2016-09-12
#cat >>conf/distributions <<END
#
#Origin: ${origin}
#Label: MariaDB
#Codename: wheezy
#Architectures: ${architectures}
#Components: main
#Description: ${description}
#SignWith: ${gpg_key}
#END
#
#case ${TREE} in 
#  '5.5'|'5.5e'|'5.5-galera'|'5.5e-galera')
#    #debian_dists='"squeeze debian6" "wheezy wheezy"'
#    #debian_dists="${squeeze} wheezy"
#    debian_dists="wheezy"
#    ;;
#  '10.0e'|'10.0e-galera')
#    #debian_dists="${squeeze} wheezy jessie"
#    debian_dists="wheezy jessie"
#cat >>conf/distributions <<END
#
#Origin: ${origin}
#Label: MariaDB
#Codename: jessie
#Architectures: ${architectures}
#Components: main
#Description: ${description}
#SignWith: ${gpg_key}
#END
#    ;;
#  *)
#    #debian_dists='"squeeze debian6" "wheezy wheezy" "sid sid"'
#    #debian_dists="${squeeze} wheezy jessie sid"
#    debian_dists="wheezy jessie sid"
#cat >>conf/distributions <<END
#
#Origin: ${origin}
#Label: MariaDB
#Codename: jessie
#Architectures: ${architectures}
#Components: main
#Description: ${description}
#SignWith: ${gpg_key}
#
#Origin: ${origin}
#Label: MariaDB
#Codename: sid
#Architectures: ${architectures}
#Components: main
#Description: ${description}
#SignWith: ${gpg_key_2016}
#END
#    ;;
#esac

# Remove packages from deprecated distros (if they are present)
#reprepro --basedir=. --delete clearvanished

declare -A builder_dir_ci_amd64=([bullseye]=debian-11-deb-autobake [bookworm]=debian-12-deb-autobake [trixie]=debian-13-deb-autobake [sid]=debian-sid-deb-autobake)
declare -A builder_dir_bb_amd64=([bullseye]=kvm-deb-bullseye-amd64 [bookworm]=kvm-deb-bookworm-amd64 [trixie]=kvm-deb-trixie-amd64   [sid]=kvm-deb-sid-amd64)

declare -A builder_dir_ci_aarch64=([bullseye]=aarch64-debian-11-deb-autobake [bookworm]=aarch64-debian-12-deb-autobake [trixie]=aarch64-debian-13-deb-autobake [sid]=aarch64-debian-sid-deb-autobake)
declare -A builder_dir_bb_aarch64=([bullseye]=kvm-deb-bullseye-aarch64 [bookworm]=kvm-deb-bookworm-aarch64 [trixie]=kvm-deb-trixie-aarch64 [sid]=kvm-deb-sid-aarch64)

declare -A builder_dir_ci_ppc64le=([bookworm]=ppc64le-debian-12-deb-autobake [trixie]=ppc64le-debian-13-deb-autobake [sid]=ppc64le-debian-sid-deb-autobake)
declare -A builder_dir_bb_ppc64le=([bookworm]=kvm-deb-bookworm-ppc64le [trixie]=kvm-deb-bookworm-ppc64le [sid]=kvm-deb-sid-ppc64le)

declare -A builder_dir_ci_x86=([trixie]=x86-debian-13-deb-autobake [sid]=32bit-debian-sid-deb-autobake)
declare -A builder_dir_bb_x86=([trixie]=kvm-deb-trixie-x86 [sid]=kvm-deb-sid-x86)

case ${TREE} in 
  *10.5*|*10.6*|*10.8*|*10.9*|*10.10*)
    debian_dists="bullseye"
    ;;
  *10.11*|*11.1*|*11.2*|*11.3*|*11.4*|*11.7*)
    debian_dists="bullseye bookworm"
    ;;
  *)
    debian_dists="bullseye bookworm trixie sid"
    ;;
esac

# Add packages
for dist in ${debian_dists}; do
  #set $i
  #echo $1
  echo
  line
  echo + ${dist}
  line
  if [ "${dist}" = "squeeze" ];then
    builder="debian6"
  else
    builder="${dist}"
  fi

  case ${dist} in
    bullseye) dist_alt='deb11' ;;
    bookworm) dist_alt='deb12' ;;
    trixie)   dist_alt='deb13' ;;
    sid)      dist_alt='debsid' ;;
  esac


  # add amd64 files
  builder_dir="builder_dir_${build_type}_amd64[${builder}]"
  case ${builder} in 
    'jessie')
      runCommand reprepro --basedir=. include ${dist} $ARCHDIR/${!builder_dir}/debs/mariadb-*_amd64.changes
      ;;
    'bullseye'|'bookworm'|'trixie')
      runCommand reprepro --basedir=. --ignore=wrongsourceversion include ${dist} $(find $ARCHDIR/${!builder_dir}/ -name mariadb*_amd64.changes)
      ;;
    'sid')
      runCommand reprepro --basedir=. --ignore=wrongdistribution --ignore=wrongsourceversion include ${dist} $(find $ARCHDIR/${!builder_dir}/ -name mariadb*_amd64.changes)
      ;;
    * )
      for i in $(find "$ARCHDIR/${!builder_dir}/" -name '*.deb'); do runCommand reprepro --basedir=. includedeb ${dist} $i ; done
      for i in $(find "$ARCHDIR/${!builder_dir}/" -name '*.dsc'); do runCommand reprepro --basedir=. includedsc ${dist} $i ; done
      ;;
  esac

  # add ppc64el files
  builder_dir="builder_dir_${build_type}_ppc64le[${builder}]"
  case ${builder} in
    'bookworm'|'trixie')
      for i in $(find "$ARCHDIR/${!builder_dir}/" -name '*_ppc64el.deb'); do runCommand reprepro --basedir=. includedeb ${dist} $i ; done
      ;;
    'sid')
      for i in $(find "$ARCHDIR/${!builder_dir}/" -name '*_ppc64el.deb'); do runCommand reprepro --basedir=. --ignore=wrongdistribution includedeb ${dist} $i ; done
      ;;
  esac

  # add aarch64 files
  builder_dir="builder_dir_${build_type}_aarch64[${builder}]"
  case ${builder} in
    'bullseye'|'bookworm'|'trixie')
      for i in $(find "$ARCHDIR/${!builder_dir}/" -name '*_arm64.deb'); do runCommand reprepro --basedir=. includedeb ${dist} $i ; done
      ;;
    'sid')
      for i in $(find "$ARCHDIR/${!builder_dir}/" -name '*_arm64.deb'); do runCommand reprepro --basedir=. --ignore=wrongdistribution includedeb ${dist} $i ; done
      ;;
  esac

  # add x86 files
  builder_dir="builder_dir_${build_type}_x86[${builder}]"
    case ${builder} in
      'bullseye'|'bookworm')
        echo "+ no x86 packages for ${builder}"
        ;;
      'trixie'|'sid')
        for i in $(find "$ARCHDIR/${!builder_dir}/" -name '*_i386.deb'); do runCommand reprepro --basedir=. --ignore=wrongdistribution includedeb ${dist} $i ; done
        ;;
    esac

  # Add in custom jemalloc packages for distros that need them
  case  ${builder} in
    "debian6")
      for i in $(find "${dir_jemalloc}/${builder}-amd64/" -name '*_amd64.deb'); do runCommand reprepro --basedir=. includedeb ${dist} ${i} ; done
      if [ "${ENTERPRISE}" != "yes" ]; then
        for i in $(find "${dir_jemalloc}/${builder}-i386/" -name '*_i386.deb'); do runCommand reprepro --basedir=. includedeb ${dist} ${i} ; done
      fi
      ;;
    * )
      echo "+ no custom jemalloc packages for ${dist}"
      ;;
  esac

  # Copy in galera packages if requested
  if [ ${GALERA} = "yes" ]; then
    case ${TREE} in
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
      #for file in $(find "${dir_galera}/galera-${gv}-${suffix}/" -name "*${dist}*.deb"); do reprepro -S optional -P misc --basedir=. includedeb ${dist} ${file} ; done
      #case ${dist} in
      #  'jessie')
      #    echo "no galera packages for jessie... yet"
      #    ;;
      #  * )

          case ${dist} in
            "bookworm"|"sid")
              runCommand reprepro --ignore=wrongdistribution --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/${galera_name}_${gv}-${dist_filename}*_amd64.changes
              runCommand reprepro --ignore=wrongdistribution --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/${galera_name}_${gv}-${dist_filename}*_ppc64el.changes
              runCommand reprepro --ignore=wrongdistribution --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/${galera_name}_${gv}-${dist_filename}*_arm64.changes
              ;;
            "bullseye")
              runCommand reprepro --ignore=wrongdistribution --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/${galera_name}_${gv}-${dist_filename}*_amd64.changes
              runCommand reprepro --ignore=wrongdistribution --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/${galera_name}_${gv}-${dist_filename}*_arm64.changes
              ;;
            *) 
              runCommand reprepro --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/${galera_name}_${gv}-${dist_filename}*_amd64.changes
              ;;
          esac

          if [ "${ENTERPRISE}" != "yes" ]; then
            case ${dist} in
              #"sid")
              #  runCommand reprepro --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/${galera_name}_25.3.19-${dist}*_i386.changes
              #  ;;
              'bullseye'|'bookworm')
                echo "+ no x86 packages for ${dist}"
                ;;
              'sid')
                runCommand reprepro --ignore=wrongdistribution --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/${galera_name}_${gv}-${dist_filename}*_i386.changes
                ;;
              *)
                runCommand reprepro --ignore=wrongdistribution --basedir=. include ${dist} ${dir_galera}/galera-${gv}-${suffix}/deb/${galera_name}_${gv}-${dist_filename}*_i386.changes
                ;;
            esac
          fi
      #    ;;
      #esac
    done
  fi

  case ${dist} in
    "bullseye")
      case ${ARCHDIR} in
        *11.1*)
          # Copy in CMAPI package
          # should be ${dist}, but currently we use jammy package (Aug 2023)
          runCommand reprepro --basedir=. includedeb ${dist} ${dir_cmapi}/${ver_cmapi}/11.1*/jammy/mariadb-columnstore-cmapi*${ver_cmapi}*amd64.deb
          runCommand reprepro --basedir=. includedeb ${dist} ${dir_cmapi}/${ver_cmapi}/11.1*/jammy/mariadb-columnstore-cmapi*${ver_cmapi}*arm64.deb
          ;;
        *11.2*|*11.3*|*11.4*|*11.5*|*11.6*)
          # Copy in CMAPI package
          # should be ${dist}, but currently we use jammy package (Aug 2023)
          runCommand reprepro --basedir=. includedeb ${dist} ${dir_cmapi}/${ver_cmapi}/11.2*/jammy/mariadb-columnstore-cmapi*${ver_cmapi}*amd64.deb
          runCommand reprepro --basedir=. includedeb ${dist} ${dir_cmapi}/${ver_cmapi}/11.2*/jammy/mariadb-columnstore-cmapi*${ver_cmapi}*arm64.deb
          ;;
      esac
      ;;
  esac


done

# Create sums of .deb packages
echo "+ md5sum    ./pool/main/*/*/*.deb >> md5sums.txt"
        md5sum    ./pool/main/*/*/*.deb >> md5sums.txt
echo "+ sha1sum   ./pool/main/*/*/*.deb >> sha1sums.txt"
        sha1sum   ./pool/main/*/*/*.deb >> sha1sums.txt
echo "+ sha256sum ./pool/main/*/*/*.deb >> sha256sums.txt"
        sha256sum ./pool/main/*/*/*.deb >> sha256sums.txt
echo "+ sha512sum ./pool/main/*/*/*.deb >> sha512sums.txt"
        sha512sum ./pool/main/*/*/*.deb >> sha512sums.txt

