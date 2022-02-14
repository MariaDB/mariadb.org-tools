#!/bin/bash - 
#===============================================================================
#
#          FILE:  mkrepo-yum.sh
# 
#         USAGE:  ./mkrepo-yum.sh <archive_dir>
# 
#   DESCRIPTION:  A script to generate the yum repositories for our RPM
#                 packages.
#
#                 The script copies files from the archive directory into
#                 separate directories for each distribution/cpu combination
#                 (just like they are stored in the archive directory). For
#                 best results, it should be run within an empty directory.
#
#                 After running the script, the directories are uploaded to the
#                 YUM server, replacing the previous version in that series
#                 (i.e. the 5.5.23 files are replaced by the 5.5.24 files and
#                 the 5.3.6 files are replaced by the 5.3.7 files, and so on).
# 
#===============================================================================

umask 002

#killall gpg-agent
# Right off the bat we want to log everything we're doing and exit immediately
# if there's an error
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

ARCHDIR="$3"                      # path to x86 & x86_64 packages
P8_ARCHDIR="$4"                   # path to ppc64 packages (optional)

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

declare -A builder_dir_ci_amd64=(
  [centos7]=amd64-centos-7-rpm-autobake [centos8]=amd64-centos-8-rpm-autobake
  [rhel7]=amd64-rhel-7-rpm-autobake [rhel8]=amd64-rhel-8-rpm-autobake
  [fedora34]=amd64-fedora-34-rpm-autobake [fedora35]=amd64-fedora-35-rpm-autobake
  [sles12]=amd64-sles-12-rpm-autobake [sles15]=amd64-sles-15-rpm-autobake
  [opensuse15]=amd64-opensuse-15-rpm-autobake [opensuse42]=amd64-opensuse-42-rpm-autobake
)

declare -A builder_dir_bb_amd64=(
  [centos7]=kvm-rpm-centos74-amd64 [centos8]=kvm-rpm-centos8-amd64
  [rhel7]=kvm-rpm-rhel7-amd64 [rhel8]=kvm-rpm-rhel8-amd64
  [fedora34]=kvm-rpm-fedora34-amd64 [fedora35]=kvm-rpm-fedora35-amd64
  [sles12]=kvm-zyp-sles125-amd64 [sles15]=kvm-zyp-sles150-amd64
  [opensuse15]=kvm-zyp-opensuse150-amd64 [opensuse42]=kvm-zyp-opensuse42-amd64
)

# - - - - - - - - -

declare -A builder_dir_ci_aarch64=(
  [centos7]=aarch64-centos-7-rpm-autobake [centos8]=aarch64-centos-8-rpm-autobake
  [rhel7]=aarch64-rhel-7-rpm-autobake [rhel8]=aarch64-rhel-8-rpm-autobake
  [fedora34]=aarch64-fedora-34-rpm-autobake [fedora35]=aarch64-fedora-35-rpm-autobake
  [sles12]=aarch64-sles-12-rpm-autobake [sles15]=aarch64-sles-15-rpm-autobake
  [opensuse15]=aarch64-opensuse-15-rpm-autobake [opensuse42]=aarch64-opensuse-42-rpm-autobake
)

declare -A builder_dir_bb_aarch64=(
  [centos7]=kvm-rpm-centos74-aarch64 [centos8]=kvm-rpm-centos8-aarch64
  [rhel7]=kvm-rpm-centos74-aarch64 [rhel8]=kvm-rpm-rhel8-aarch64
  [fedora34]=kvm-rpm-fedora34-aarch64 [fedora35]=kvm-rpm-fedora35-aarch64
  [sles12]=kvm-zyp-sles123-aarch64 [sles15]=kvm-zyp-sles150-aarch64
  [opensuse15]=kvm-zyp-opensuse150-aarch64 [opensuse42]=kvm-zyp-opensuse42-aarch64
)

# - - - - - - - - -

declare -A builder_dir_ci_ppc64le=(
  [centos7]=ppc64le-centos-7-rpm-autobake [centos8]=ppc64le-centos-8-rpm-autobake
  [rhel7]=ppc64le-rhel-7-rpm-autobake [rhel8]=ppc64le-rhel-8-rpm-autobake
  [fedora34]=ppc64le-fedora-34-rpm-autobake [fedora35]=ppc64le-fedora-35-rpm-autobake
  [sles12]=ppc64le-sles-12-rpm-autobake [sles15]=ppc64le-sles-15-rpm-autobake
  [opensuse15]=ppc64le-opensuse-15-rpm-autobake [opensuse42]=ppc64le-opensuse-42-rpm-autobake
)

declare -A builder_dir_bb_ppc64le=(
  [centos7]=kvm-rpm-centos73-ppc64le [centos8]=kvm-rpm-centos8-ppc64le
  [rhel7]=kvm-rpm-rhel7-ppc64le [rhel8]=kvm-rpm-rhel8-ppc64le
  [fedora34]=kvm-rpm-fedora34-ppc64le [fedora35]=kvm-rpm-fedora35-ppc64le
  [sles12]=kvm-zyp-sles123-ppc64le [sles15]=kvm-zyp-sles150-ppc64le
  [opensuse15]=kvm-zyp-opensuse150-ppc64le [opensuse42]=kvm-zyp-opensuse42-ppc64le
)

declare -A builder_dir_bb_ppc64=(
  [centos7]=kvm-rpm-centos73-ppc64
)

case ${ARCHDIR} in
  *10.5*|*10.6*|*10.7*|*10.8*)
  dists_bb="
    centos7-amd64
    centos7-ppc64
    centos7-ppc64le
    centos7-aarch64

    rhel8-amd64
    rhel8-aarch64
    rhel8-ppc64le

    fedora34-amd64
    fedora34-aarch64
    fedora35-amd64
    fedora35-aarch64

    opensuse15-amd64

    sles12-amd64
    sles15-amd64
  "
  dists_ci="
    rhel8-aarch64

    fedora34-amd64
    fedora34-aarch64
    fedora35-amd64
    fedora35-aarch64
  "
  dists=${dists_bb}
    ;;
  *10.4*)
  dists_bb="
    centos7-amd64
    centos7-ppc64
    centos7-ppc64le
    centos7-aarch64

    rhel8-amd64
    rhel8-aarch64
    rhel8-ppc64le

    opensuse15-amd64

    sles12-amd64
    sles15-amd64
  "
  dists_ci="
    rhel8-aarch64
  "
  dists=${dists_bb}
    ;;
  *10.3*)
  dists_bb="
    centos7-amd64
    centos7-ppc64
    centos7-ppc64le
    centos7-aarch64

    rhel8-amd64
    rhel8-aarch64
    rhel8-ppc64le

    opensuse15-amd64

    sles12-amd64
    sles15-amd64
  "
  dists_ci="
    rhel8-aarch64
  "
  dists=${dists_bb}
    ;;
  *10.2*)
  dists_bb="
    centos7-amd64
    centos7-ppc64
    centos7-ppc64le
    centos7-aarch64

    opensuse15-amd64

    sles12-amd64
    sles15-amd64
  "
  dists_ci="
  "
  dists=${dists_bb}
    ;;
esac

suffix="signed"

#-------------------------------------------------------------------------------
#  Functions
#-------------------------------------------------------------------------------
loadDefaults() {
  # Load the paths and other settings (if they exist)
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

runCommand() {
  # This function emulates the behavior of "set -x", while giving us greater
  # control over the output
  echo "+ ${@}"
  #sleep 1
  if ${@} ; then
    return 0
  else
    return 1
  fi
}

line() {
  echo "-------------------------------------------------------------------------------"
}

thickline() {
  echo "==============================================================================="
}

maybe_make_symlink() {
  # This function takes two arguments, a link_target (${1}) and a link_name (${2})

  # Fail if either of them are empty
  if [ -z "${2}" ]; then
    thickline
    echo "+ Failure: the maybe_make_symlink function requires two arguments"
    thickline
    exit
  fi

  # Check to see if ${1} and ${2} are the same
  if [ "${1}" -ef "${2}" ]; then
    # if they are the same, show the link and where it points
    ls -ld ${2}
  else
    # if they are not the same, create the link, overwriting whatever is there
    runCommand ln -svf ${1} ${2}
    # show the link and where it points
    ls -ld ${2}
  fi
}

copy_files() {
  # This function takes as an argument, the file portion of an rsync command

  # copy the files from the source to the destination
  echo "+ rsync -a --info=progress2 --keep-dirlinks ${@}"
          rsync -a --info=progress2 --keep-dirlinks ${@}

}

set_builder_dir() {
  local builder_dist=${1}
  local builder_arch=${2}

  builder_dir="builder_dir_${build_type}_${builder_arch}[${builder_dist}]"
}

check_updateinfo() {
  if xmlstarlet val ${1} ; then
    echo "${1} is valid xml"
  else
    thickline
    echo "+ ${1} is not valid xml, something went wrong"
    thickline
    exit 5
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
    echo 1>&2 "Usage: $0 <galera?> <enterprise?> <archive directory> [p8_dir]"
    echo 1>&2 "For <galera?> and <enterprise?> : yes or no"
    echo 1>&2 "[p8_dir] is optional"
    exit 1
fi

# After this point, we tread unset variables as an error
set -u
  # -u  Treat unset variables as an error when performing parameter expansion.
  #     An error message will be written to the standard error, and a
  #     non-interactive shell will exit.

case ${ARCHDIR} in
  *10.2*|*10.3*)
    ver_galera_real=${ver_galera}
    ;;
  *)
    ver_galera_real=${ver_galera4}
    ;;
esac



# Copy over the packages
for REPONAME in ${dists}; do
  case "${REPONAME}" in
    'centos6-x86')
      set_builder_dir centos6 x86
      runCommand mkdir -vp rhel/6/i386
      maybe_make_symlink rhel/6/i386 rhel6-x86
      maybe_make_symlink rhel6-x86 centos6-x86

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/${!builder_dir}/ ./${REPONAME}/"

      # Copy in Galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done

      # Copy in other files
      copy_files "${dir_jemalloc}/jemalloc-${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"
      copy_files "${dir_libzstd}/${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"

      ;;
    'centos6-amd64')
      set_builder_dir centos6 amd64
      runCommand mkdir -vp rhel/6/x86_64
      pushd rhel/
        for i in $(seq 0 9); do
          maybe_make_symlink 6 6.${i}
        done
        maybe_make_symlink 6 6Server
        maybe_make_symlink 6 6Client
      popd
      maybe_make_symlink rhel/6/x86_64 rhel6-amd64
      maybe_make_symlink rhel6-amd64 centos6-amd64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/${!builder_dir}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      
      # Copy in other files
      copy_files "${dir_jemalloc}/jemalloc-${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"
      copy_files "${dir_libzstd}/${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"
      ;;
    'centos74-amd64'|'centos7-amd64')
      set_builder_dir centos7 amd64
      runCommand mkdir -vp rhel/7/x86_64
      case ${ARCHDIR} in
        *10.6*|*10.7*)
          echo "+ no symlinks for ${ARCHDIR}"
          ;;
        *)
      pushd rhel/
        for i in $(seq 0 7); do
          maybe_make_symlink 7 7.${i}
        done
        maybe_make_symlink 7 7Server
        maybe_make_symlink 7 7Client
      popd
          ;;
      esac
      maybe_make_symlink rhel/7/x86_64 rhel7-amd64
      maybe_make_symlink rhel7-amd64 rhel74-amd64
      maybe_make_symlink rhel7-amd64 rhel73-amd64
      maybe_make_symlink rhel7-amd64 centos7-amd64
      maybe_make_symlink centos7-amd64 centos74-amd64
      maybe_make_symlink centos7-amd64 centos73-amd64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/${!builder_dir}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/centos74-amd64/galera*.rpm ${REPONAME}/rpms/"
      done

      # Copy in other files
      case ${ARCHDIR} in
        *10.5*|*10.6*|*10.7*)
          echo "+ no jemalloc for ${ARCHDIR}"
          ;;
        *)
      copy_files "${dir_jemalloc}/jemalloc-centos74-amd64-${suffix}/*.rpm ./${REPONAME}/rpms/"
          ;;
      esac
      copy_files "${dir_libzstd}/centos74-amd64-${suffix}/*.rpm ./${REPONAME}/rpms/"
      ;;
    'centos73-amd64')
      set_builder_dir centos7 amd64
      runCommand mkdir -vp rhel/7/x86_64
      case ${ARCHDIR} in
        *10.6*|*10.7*)
          echo "+ no symlinks for ${ARCHDIR}"
          ;;
        *)
      pushd rhel/
        for i in $(seq 0 5); do
          maybe_make_symlink 7 7.${i}
        done
        maybe_make_symlink 7 7Server
        maybe_make_symlink 7 7Client
      popd
          ;;
      esac
      maybe_make_symlink rhel/7/x86_64 rhel7-amd64
      maybe_make_symlink rhel7-amd64 rhel73-amd64
      maybe_make_symlink rhel7-amd64 rhel74-amd64
      maybe_make_symlink rhel7-amd64 centos7-amd64
      maybe_make_symlink centos7-amd64 centos74-amd64
      maybe_make_symlink centos7-amd64 centos73-amd64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/${!builder_dir}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      
      # Copy in other files
      case ${ARCHDIR} in
        *10.5*|*10.6*|*10.7*)
          echo "+ no jemalloc for ${ARCHDIR}"
          ;;
        *)
      copy_files "${dir_jemalloc}/jemalloc-${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"
          ;;
      esac
      copy_files "${dir_libzstd}/${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"
      ;;
    'centos73-ppc64'|'centos7-ppc64')
      set_builder_dir centos7 ppc64
      runCommand mkdir -vp rhel/7/ppc64
      maybe_make_symlink rhel/7/ppc64 rhel7-ppc64
      maybe_make_symlink rhel7-ppc64 rhel73-ppc64
      maybe_make_symlink rhel7-ppc64 centos7-ppc64
      maybe_make_symlink centos7-ppc64 centos73-ppc64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/${!builder_dir}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      
      # Copy in other files
      case ${ARCHDIR} in
        *10.5*|*10.6*|*10.7*)
          echo "+ no jemalloc for ${ARCHDIR}"
          ;;
        *)
      copy_files "${dir_jemalloc}/jemalloc-${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"
          ;;
      esac
      copy_files "${dir_libzstd}/${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"
      ;;
    'centos73-ppc64le'|'centos7-ppc64le')
      set_builder_dir centos7 ppc64le
      runCommand mkdir -vp rhel/7/ppc64le
      maybe_make_symlink rhel/7/ppc64le rhel7-ppc64le
      maybe_make_symlink rhel7-ppc64le rhel73-ppc64le
      maybe_make_symlink rhel7-ppc64le centos7-ppc64le
      maybe_make_symlink centos7-ppc64le centos73-ppc64le

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/${!builder_dir}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      
      # Copy in other files
      copy_files "${dir_libzstd}/${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"
      ;;
    'centos74-aarch64'|'centos7-aarch64'|'rhel7-aarch64')
      set_builder_dir rhel7 aarch64
      runCommand mkdir -vp rhel/7/aarch64
      maybe_make_symlink rhel/7/aarch64 rhel7-aarch64
      maybe_make_symlink rhel7-aarch64 rhel74-aarch64
      maybe_make_symlink rhel7-aarch64 centos7-aarch64
      maybe_make_symlink centos7-aarch64 centos74-aarch64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/${!builder_dir}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/centos74-aarch64/galera*.rpm ${REPONAME}/rpms/"
      done
      
      # Copy in other files
      case ${ARCHDIR} in
        *10.5*|*10.6*|*10.7*)
          echo "+ no jemalloc for ${ARCHDIR}"
          ;;
        *)
      copy_files "${dir_jemalloc}/jemalloc-centos74-aarch64-${suffix}/*.rpm ./${REPONAME}/rpms/"
          ;;
      esac
      copy_files "${dir_libzstd}/centos74-aarch64-${suffix}/*.rpm ./${REPONAME}/rpms/"
      ;;
    'rhel8-aarch64')
      set_builder_dir rhel8 aarch64
      runCommand mkdir -vp rhel/8/aarch64
      maybe_make_symlink rhel/8/aarch64 rhel8-aarch64
      maybe_make_symlink rhel8-aarch64 rhel8-aarch64
      maybe_make_symlink rhel8-aarch64 centos8-aarch64
      maybe_make_symlink centos8-aarch64 centos8-aarch64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/${!builder_dir}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      ;;
    'rhel8-amd64')
      set_builder_dir rhel8 amd64
      runCommand mkdir -vp rhel/8/x86_64
      maybe_make_symlink rhel/8/x86_64 rhel8-amd64
      maybe_make_symlink rhel8-amd64 centos8-amd64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/${!builder_dir}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      ;;
    'rhel8-ppc64le')
      set_builder_dir rhel8 ppc64le
      runCommand mkdir -vp rhel/8/ppc64le/rpms
      runCommand mkdir -vp rhel/8/ppc64le/srpms
      maybe_make_symlink rhel/8/ppc64le rhel8-ppc64le
      maybe_make_symlink rhel8-ppc64le centos8-ppc64le

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/${!builder_dir}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      ;;
    fedora*)
      case ${REPONAME} in
        fedora34-amd64) fedora_ver=34 ; fedora_arch=amd64 ;;
        fedora35-amd64) fedora_ver=35 ; fedora_arch=amd64 ;;

        fedora34-aarch64) fedora_ver=34 ; fedora_arch=aarch64 ;;
        fedora35-aarch64) fedora_ver=35 ; fedora_arch=aarch64 ;;

        fedora34-ppc64le) fedora_ver=34 ; fedora_arch=ppc64le ;;
        fedora35-ppc64le) fedora_ver=35 ; fedora_arch=ppc64le ;;
      esac
      case ${fedora_arch} in
        amd64) fedora_arch_real=x86_64 ;;
        *) fedora_arch_real=${fedora_arch} ;;
      esac
      set_builder_dir fedora${fedora_ver} ${fedora_arch}
      runCommand mkdir -vp fedora/${fedora_ver}/${fedora_arch_real}
      maybe_make_symlink fedora/${fedora_ver}/${fedora_arch_real} ${REPONAME}

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/${!builder_dir}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      ;;
    'opensuse150-amd64'|'opensuse15-amd64')
      set_builder_dir opensuse15 amd64
      runCommand mkdir -vp opensuse/15/x86_64
      maybe_make_symlink opensuse/15/x86_64 opensuse150-amd64
      maybe_make_symlink opensuse/15/x86_64 opensuse15-amd64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/${!builder_dir}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/opensuse150-amd64/galera*.rpm ${REPONAME}/rpms/"
      done
      ;;
    'opensuse42-amd64')
      set_builder_dir opensuse42 amd64
      runCommand mkdir -vp opensuse/42/x86_64
      maybe_make_symlink opensuse/42/x86_64 opensuse42-amd64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/${!builder_dir}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      ;;
    'sles114-x86')
      set_builder_dir sles11 x86
      runCommand mkdir -vp sles/11/i386
      maybe_make_symlink sles/11/i386 sles11-x86
      maybe_make_symlink sles11-x86 sles114-x86

      # Copy in MariaDB files
      echo "+ rsync -av --keep-dirlinks ${ARCHDIR}/${!builder_dir}/ ./${REPONAME}/"
              rsync -av --keep-dirlinks ${ARCHDIR}/${!builder_dir}/ ./${REPONAME}/

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/sles11-x86/galera*.rpm ${REPONAME}/rpms/"
      done
      ;;
    'sles114-amd64')
      set_builder_dir sles11 amd64
      runCommand mkdir -vp sles/11/x86_64
      maybe_make_symlink sles/11/x86_64 sles11-amd64
      maybe_make_symlink sles11-amd64 sles114-amd64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/${!builder_dir}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/sles11-amd64/galera*.rpm ${REPONAME}/rpms/"
      done
      ;;
    'sles12-amd64')
      set_builder_dir sles12 amd64
      runCommand mkdir -vp sles/12/x86_64
      maybe_make_symlink sles/12/x86_64 sles12-amd64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/${!builder_dir}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      
      # Copy in other files
      copy_files "${dir_nmap}/x86_64/${ver_nmap}-${suffix}/rpms/*.rpm ./${REPONAME}/rpms/"
      ;;
    'sles12-ppc64le')
      set_builder_dir sles12 ppc64le
      runCommand mkdir -vp sles/12/ppc64le
      maybe_make_symlink sles/12/ppc64le sles12-ppc64le

      # Copy in MariaDB files
      copy_files "${P8_ARCHDIR}/p8-suse12-rpm/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      ;;
    'sles150-amd64'|'sles15-amd64')
      set_builder_dir sles15 amd64
      runCommand mkdir -vp sles/15/x86_64
      maybe_make_symlink sles/15/x86_64 sles150-amd64
      maybe_make_symlink sles/15/x86_64 sles15-amd64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/${!builder_dir}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/sles150-amd64/galera*.rpm ${REPONAME}/rpms/"
      done
      ;;
    *)
      # We should not ever reach this, error
      thickline
      echo "+ Unexpected value, REPONAME=${REPONAME}"
      thickline
      exit 1
      ;;
  esac
done

# Add centos link to rhel dir
maybe_make_symlink rhel centos

# Sign all the rpms with the appropriate key
rpmsign --addsign --key-id=${gpg_key} $(find . -name '*.rpm')

for DIR in ${dists}; do
  echo
  line
  echo "+ Processing ${DIR}"
  line
  runCommand cd ${DIR}
  pwd
  for sum in md5 sha1 sha256 sha512; do
    if [ -e ${sum}sums.txt ]; then
      runCommand rm -v ${sum}sums.txt
    fi
    ${sum}sum $(find . -name '*.rpm') >> ${sum}sums.txt
    echo
    runCommand ${sum}sum -c ${sum}sums.txt
  done

  cd ..

  echo

  # Create the repository and sign the repomd.xml file
  case ${DIR} in
    'sles114-amd64'|'sles114-x86')
      runCommand createrepo -s sha --update --database --pretty ${DIR}
      ;;
    *)
      runCommand createrepo --update --database --pretty ${DIR}
      ;;
  esac

  # MDEV-22638 - Provide updateinfo.xml repository info for yum / dnf

  case ${DIR} in
    centos7*)
      runCommand ${GEN_UPDATEINFO} --repository ${DIR}/ --platform-name RedHat --platform-version 7
      ;;
    rhel8*)
      runCommand ${GEN_UPDATEINFO} --repository ${DIR}/ --platform-name RedHat --platform-version 8
      ;;
    fedora34*)
      runCommand ${GEN_UPDATEINFO} --repository ${DIR}/ --platform-name Fedora --platform-version 34
      ;;
    fedora35*)
      runCommand ${GEN_UPDATEINFO} --repository ${DIR}/ --platform-name Fedora --platform-version 35
      ;;
    sles12*)
      runCommand ${GEN_UPDATEINFO} --repository ${DIR}/ --platform-name SUSE --platform-version 12
      ;;
    sles15*)
      runCommand ${GEN_UPDATEINFO} --repository ${DIR}/ --platform-name SUSE --platform-version 15
      ;;
    opensuse15*)
      runCommand ${GEN_UPDATEINFO} --repository ${DIR}/ --platform-name openSUSE --platform-version 15
      ;;
    *)
      thickline
      echo "+ Unexpected repository value of ${DIR}"
      thickline
      exit 1
      ;;
  esac

  check_updateinfo ./updateinfo.xml
  runCommand modifyrepo ./updateinfo.xml ${DIR}/repodata
  runCommand rm -v ./updateinfo.xml
  
  echo 

  # if the signature file exists, remove it
  if [ -e ${DIR}/repodata/repomd.xml.asc ]; then
    runCommand rm -v ${DIR}/repodata/repomd.xml.asc
  fi

  # sign the repomod.xml file
  runCommand gpg2 --detach-sign --armor -u ${gpg_key} ${DIR}/repodata/repomd.xml 

  echo 
  # Add a README to the srpms directory
  if [ ! -d ${DIR}/srpms ] ;then
    runCommand mkdir -vp ${DIR}/srpms
    echo "Why do MariaDB RPMs not include the source RPM (SRPMS)?
https://mariadb.com/kb/en/why-do-mariadb-rpms-not-include-the-source-rpm-srpms
" > ${DIR}/srpms/README
  fi
done


# vim: filetype=sh
