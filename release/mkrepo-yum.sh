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

#-------------------------------------------------------------------------------
#  Variables which are not set dynamically (because they don't change often)
#-------------------------------------------------------------------------------

# set location of prep.conf and prep.log to XDG-compatible directories and then
# create them if they don't exist
dir_conf=${XDG_CONFIG_HOME:-~/.config}
dir_log=${XDG_DATA_HOME:-~/.local/share}


# If we are on 5.5 then no fedora
if [[ "${ARCHDIR}" == *"5.5"* ]]; then
  dists="
    centos6-x86
    centos6-amd64

    centos73-amd64
    centos73-ppc64
    centos73-ppc64le

    centos74-aarch64

    sles114-x86
    sles114-amd64
  "
elif [[ "${ARCHDIR}" == *"10.0"* ]]; then
  dists="
    centos6-amd64
    centos6-x86

    centos73-amd64
    centos73-ppc64
    centos73-ppc64le

    centos74-aarch64

    opensuse42-amd64

    sles114-amd64
    sles114-x86

    sles12-amd64
    sles12-ppc64le
  "
elif [[ "${ARCHDIR}" = *"10.1"* ]]; then
  dists="
    centos6-amd64
    centos6-x86

    centos73-amd64
    centos73-ppc64
    centos73-ppc64le

    centos74-aarch64

    opensuse42-amd64

    sles114-amd64
    sles114-x86

    sles12-amd64
    sles12-ppc64le
  "
elif [[ "${ARCHDIR}" = *"10.4"* ]]; then
  dists="
    centos73-amd64
    centos73-ppc64
    centos73-ppc64le

    centos74-aarch64

    rhel8-amd64

    fedora28-amd64
    fedora29-amd64

    opensuse42-amd64
    opensuse150-amd64

    sles12-amd64
    sles150-amd64
  "
elif [[ "${ARCHDIR}" = *"10.3"* ]]; then
  dists="
    centos6-amd64
    centos6-x86

    centos73-amd64
    centos73-ppc64
    centos73-ppc64le

    centos74-aarch64

    rhel8-amd64

    fedora28-amd64
    fedora29-amd64

    opensuse42-amd64
    opensuse150-amd64

    sles12-amd64
    sles12-ppc64le
    sles150-amd64
  "
elif [[ "${ARCHDIR}" = *"10.2"* ]]; then
  dists="
    centos6-amd64
    centos6-x86

    centos73-amd64
    centos73-ppc64
    centos73-ppc64le

    centos74-aarch64

    fedora28-amd64

    opensuse42-amd64
    opensuse150-amd64

    sles12-amd64
    sles12-ppc64le
    sles150-amd64
  "
fi

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
  if [ "${2}" -ef "${2}" ]; then
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
  *10.4*)
    ver_galera_real=${ver_galera4}
    ;;
  *)
    ver_galera_real=${ver_galera}
    ;;
esac

# Copy over the packages
for REPONAME in ${dists}; do
  case "${REPONAME}" in
    'centos6-x86')
      runCommand mkdir -vp rhel/6/i386
      maybe_make_symlink rhel/6/i386 rhel6-x86
      maybe_make_symlink rhel6-x86 centos6-x86

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/kvm-rpm-${REPONAME}/ ./${REPONAME}/"

      # Copy in Galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done

      # Copy in other files
      copy_files "${dir_jemalloc}/jemalloc-${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"
      copy_files "${dir_libzstd}/${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"

      ;;
    'centos6-amd64')
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
      copy_files "${ARCHDIR}/kvm-rpm-${REPONAME}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      
      # Copy in other files
      copy_files "${dir_jemalloc}/jemalloc-${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"
      copy_files "${dir_libzstd}/${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"
      ;;
    'centos73-amd64')
      runCommand mkdir -vp rhel/7/x86_64
      pushd rhel/
        for i in $(seq 0 3); do
          maybe_make_symlink 7 7.${i}
        done
        maybe_make_symlink 7 7Server
        maybe_make_symlink 7 7Client
      popd
      maybe_make_symlink rhel/7/x86_64 rhel7-amd64
      maybe_make_symlink rhel7-amd64 rhel73-amd64
      maybe_make_symlink rhel7-amd64 centos7-amd64
      maybe_make_symlink centos7-amd64 centos73-amd64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/kvm-rpm-${REPONAME}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      
      # Copy in other files
      copy_files "${dir_jemalloc}/jemalloc-${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"
      copy_files "${dir_libzstd}/${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"
      ;;
    'centos73-ppc64')
      runCommand mkdir -vp rhel/7/ppc64
      maybe_make_symlink rhel/7/ppc64 rhel7-ppc64
      maybe_make_symlink rhel7-ppc64 rhel73-ppc64
      maybe_make_symlink rhel7-ppc64 centos7-ppc64
      maybe_make_symlink centos7-ppc64 centos73-ppc64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/kvm-rpm-${REPONAME}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      
      # Copy in other files
      copy_files "${dir_jemalloc}/jemalloc-${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"
      copy_files "${dir_libzstd}/${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"
      ;;
    'centos73-ppc64le')
      runCommand mkdir -vp rhel/7/ppc64le
      maybe_make_symlink rhel/7/ppc64le rhel7-ppc64le
      maybe_make_symlink rhel7-ppc64le rhel73-ppc64le
      maybe_make_symlink rhel7-ppc64le centos7-ppc64le
      maybe_make_symlink centos7-ppc64le centos73-ppc64le

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/kvm-rpm-${REPONAME}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      
      # Copy in other files
      copy_files "${dir_libzstd}/${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"
      ;;
    'centos74-aarch64')
      runCommand mkdir -vp rhel/7/aarch64
      maybe_make_symlink rhel/7/aarch64 rhel7-aarch64
      maybe_make_symlink rhel7-aarch64 rhel74-aarch64
      maybe_make_symlink rhel7-aarch64 centos7-aarch64
      maybe_make_symlink centos7-aarch64 centos74-aarch64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/kvm-rpm-${REPONAME}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      
      # Copy in other files
      copy_files "${dir_jemalloc}/jemalloc-${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"
      copy_files "${dir_libzstd}/${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"
      ;;
    'centos74-amd64')
      runCommand mkdir -vp rhel/7.4/x86_64
      maybe_make_symlink rhel/7.4/x86_64 rhel74-amd64
      maybe_make_symlink rhel74-amd64 centos74-amd64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/kvm-rpm-${REPONAME}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      
      # Copy in other files
      copy_files "${dir_jemalloc}/jemalloc-${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"
      copy_files "${dir_libzstd}/${REPONAME}-${suffix}/*.rpm ./${REPONAME}/rpms/"
      ;;
    'rhel8-amd64')
      runCommand mkdir -vp rhel/8/x86_64
      maybe_make_symlink rhel/8/x86_64 rhel8-amd64
      maybe_make_symlink rhel8-amd64 centos8-amd64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/kvm-rpm-${REPONAME}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done

      ;;
    'fedora25-x86')
      runCommand mkdir -vp fedora/25/i386
      maybe_make_symlink fedora/25/i386 fedora25-x86

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/kvm-rpm-${REPONAME}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      ;;
    'fedora25-amd64')
      runCommand mkdir -vp fedora/25/x86_64
      maybe_make_symlink fedora/25/x86_64 fedora25-amd64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/kvm-rpm-${REPONAME}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      ;;
    'fedora26-amd64')
      runCommand mkdir -vp fedora/26/x86_64
      maybe_make_symlink fedora/26/x86_64 fedora26-amd64

      # Copy in MariaDB files
      echo "+ rsync -a --info=progress2 --keep-dirlinks ${ARCHDIR}/kvm-rpm-${REPONAME}/ ./${REPONAME}/"
              rsync -a --info=progress2 --keep-dirlinks ${ARCHDIR}/kvm-rpm-${REPONAME}/ ./${REPONAME}/

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        echo "+ rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
                rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/
      done
      ;;
    'fedora28-amd64')
      runCommand mkdir -vp fedora/28/x86_64
      maybe_make_symlink fedora/28/x86_64 fedora28-amd64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/kvm-rpm-${REPONAME}/ ./${REPONAME}/"

      # Copy in galera files
      #for gv in ${ver_galera_real}; do
      #  copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      #done
      ;;
    'fedora29-amd64')
      runCommand mkdir -vp fedora/29/x86_64
      maybe_make_symlink fedora/29/x86_64 fedora29-amd64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/kvm-rpm-${REPONAME}/ ./${REPONAME}/"
      ;;
    'opensuse42-amd64')
      runCommand mkdir -vp opensuse/42/x86_64
      maybe_make_symlink opensuse/42/x86_64 opensuse42-amd64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/kvm-zyp-${REPONAME}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      ;;
    'opensuse150-amd64')
      runCommand mkdir -vp opensuse/15.0/x86_64
      maybe_make_symlink opensuse/15.0/x86_64 opensuse150-amd64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/kvm-zyp-${REPONAME}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      ;;
    'sles114-x86')
      runCommand mkdir -vp sles/11/i386
      maybe_make_symlink sles/11/i386 sles11-x86
      maybe_make_symlink sles11-x86 sles114-x86

      # Copy in MariaDB files
      echo "+ rsync -av --keep-dirlinks ${ARCHDIR}/kvm-zyp-${REPONAME}/ ./${REPONAME}/"
              rsync -av --keep-dirlinks ${ARCHDIR}/kvm-zyp-${REPONAME}/ ./${REPONAME}/

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/sles11-x86/galera*.rpm ${REPONAME}/rpms/"
      done
      ;;
    'sles114-amd64')
      runCommand mkdir -vp sles/11/x86_64
      maybe_make_symlink sles/11/x86_64 sles11-amd64
      maybe_make_symlink sles11-amd64 sles114-amd64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/kvm-zyp-${REPONAME}/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/sles11-amd64/galera*.rpm ${REPONAME}/rpms/"
      done
      ;;
    'sles12-amd64')
      runCommand mkdir -vp sles/12/x86_64
      maybe_make_symlink sles/12/x86_64 sles12-amd64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/kvm-zyp-sles123-amd64/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      
      # Copy in other files
      copy_files "${dir_nmap}/x86_64/${ver_nmap}-${suffix}/rpms/*.rpm ./${REPONAME}/rpms/"
      ;;
    'sles12-ppc64le')
      runCommand mkdir -vp sles/12/ppc64le
      maybe_make_symlink sles/12/ppc64le sles12-ppc64le

      # Copy in MariaDB files
      copy_files "${P8_ARCHDIR}/p8-suse12-rpm/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
      done
      ;;
    'sles150-amd64')
      runCommand mkdir -vp sles/15.0/x86_64
      maybe_make_symlink sles/15.0/x86_64 sles150-amd64

      # Copy in MariaDB files
      copy_files "${ARCHDIR}/kvm-zyp-sles150-amd64/ ./${REPONAME}/"

      # Copy in galera files
      for gv in ${ver_galera_real}; do
        copy_files "${dir_galera}/galera-${gv}-${suffix}/rpm/${REPONAME}/galera*.rpm ${REPONAME}/rpms/"
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
