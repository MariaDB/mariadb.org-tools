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

ARCHDIR="$3"                      # path to x86 & x86_64 packages
P8_ARCHDIR="$4"                   # path to ppc64 packages (optional)

#-------------------------------------------------------------------------------
#  Variables which are not set dynamically (because they don't change often)
#-------------------------------------------------------------------------------

# If we are on 5.5 then no fedora
if [[ "${ARCHDIR}" == *"5.5"* ]]; then
  dists="sles12 rhel6 rhel7"
  vers_maj_fedora=""                            # no Fedora in 5.5 any more
  distros="sles rhel"
  vers_maj_sles="12"
elif [[ "${ARCHDIR}" == *"10.0"* ]]; then
  dists="sles12 opensuse42 rhel6 rhel7"
  vers_maj_fedora=""                            # no Fedora in 10.0 any more
  distros="sles opensuse rhel"
  vers_maj_sles="12"
elif [[ "${ARCHDIR}" = *"10.1"* ]]; then
  dists="sles12 opensuse42 rhel6 rhel7 fedora24 fedora25"
  vers_maj_fedora="24 25"
  distros="sles opensuse rhel fedora"
  vers_maj_sles="12"
else
  dists="sles12 opensuse42 rhel6 rhel7 fedora24 fedora25"
  vers_maj_fedora="24 25"
  distros="sles opensuse rhel fedora"
  vers_maj_sles="12"
fi

# The following set the major versions of various Linux distributions for which
# we build packages.
vers_maj_opensuse="42"
vers_maj_rhel="6 7"
vers_maj_centos="6 7"

# MariaDB and MariaDB Enterprise differ as to the CPU architectures you can get
# packages for, and which gpg key is used to sign packages.
if [ "${ENTERPRISE}" = "yes" ]; then
  dists="sles12 rhel6 rhel7"
  distros="sles rhel"
  p8_dists="rhel6 rhel7 rhel71 sles12 rhel73"
  p8_architectures="ppc64 ppc64le"
  #gpg_key="0xd324876ebe6a595f"               # original enterprise key
  gpg_key="0xce1a3dd5e3c94f49"                # new enterprise key (2014-12-18)
  suffix="signed-ent"
  architectures="amd64"
  archs_std="amd64:x86_64"
  archs_rhel_6="amd64:x86_64 ppc64:ppc64"
  archs_rhel_7="amd64:x86_64 ppc64:ppc64 ppc64le:ppc64le"
  archs_sles_12="amd64:x86_64 ppc64le:ppc64le"
else
  gpg_key="0xcbcb082a1bb943db"                 # mariadb.org signing key
  p8_dists="rhel6 rhel7 rhel71 sles12 rhel73"
  #p8_dists="rhel6 rhel7 rhel71"
  p8_architectures="ppc64 ppc64le"
  suffix="signed"
  architectures="amd64 x86"
  archs_std="x86:i386 amd64:x86_64"
  archs_rhel_6=${archs_std}
  #archs_rhel_6="x86:i386 amd64:x86_64 ppc64:ppc64"
  archs_rhel_7="amd64:x86_64"
  #archs_rhel_7="amd64:x86_64 ppc64:ppc64 ppc64le:ppc64le"
  archs_sles_12="amd64:x86_64"
  #archs_sles_12="amd64:x86_64 ppc64le:ppc64le"
fi

# The following Linux distributions have the same architectures for both
# MariaDB and MariaDB Enterprise
#archs_rhel_5=${archs_std}
#archs_centos_5=${archs_std}
archs_centos_6=${archs_std}
archs_centos_7="amd64:x86_64"
#archs_fedora_19=${archs_std}
#archs_fedora_20=${archs_std}
#archs_fedora_21=${archs_std}
#archs_fedora_22=${archs_std}
#archs_fedora_23=${archs_std}
archs_fedora_24=${archs_std}
archs_fedora_25=${archs_std}
archs_sles_11=${archs_std}
archs_opensuse_13=${archs_std}
archs_opensuse_42="amd64:x86_64"

# CentOS and Redhat have minor versions that need to be accounted for in the
# dir structure. The values here are the first and last value, respectively.
# They are expanded to all the other values using the seq utility. For example,
# a value of '0 4' will be expanded to '0 1 2 3 4'.
#vers_min_centos_5="0 11"
vers_min_centos_6="0 9"
vers_min_centos_7="0 3"
#vers_min_rhel_5="0 11"
vers_min_rhel_6="0 8"
vers_min_rhel_7="0 3"

#-------------------------------------------------------------------------------
#  Functions
#-------------------------------------------------------------------------------
loadDefaults() {
  # Load the paths (if they exist)
  if [ -f ${HOME}/.prep.conf ]; then
      . ${HOME}/.prep.conf
  else
    echo
    echo "The file ${HOME}/.prep.conf does not exist in your home."
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


for distro in ${distros}; do
  eval vers_maj=\$vers_maj_${distro}
  for ver_maj in ${vers_maj}; do
    #-------------------------------------------------------------------------------
    # The following section (the eval and the for loop) is where directories
    # are created and the files are copied over (in the embedded case
    # statement). The eval pulls in the correct architecture values, which are
    # then split into an array before acting on the information.
    #-------------------------------------------------------------------------------
    eval archs=\$archs_${distro}_${ver_maj}
    for arch_pair in ${archs}; do
      arch_array=(${arch_pair//:/ })
      mkdir -vp ${distro}/${ver_maj}/${arch_array[1]}
      ln -sv ${distro}/${ver_maj}/${arch_array[1]} ${distro}${ver_maj}-${arch_array[0]}
      ARCH=${arch_array[0]}
      REPONAME="${distro}${ver_maj}"

      #case "${REPONAME}" in
      #  'rhel6')
      #    echo rsync -av --keep-dirlinks ${ARCHDIR}/kvm-rpm-centos6-${ARCH}/ ./${REPONAME}-${ARCH}/
      #    ;;
      #  'centos7'|'rhel7')
      #    if [ "${ARCH}" = "amd64" ]; then
      #      echo rsync -av --keep-dirlinks ${ARCHDIR}/kvm-rpm-centos7-${ARCH}/ ./${REPONAME}-${ARCH}/
      #    else
      #      echo "+ no packages for ${REPONAME}-${ARCH}"
      #    fi
      #    ;;
      #  'opensuse13'|'sles11')
      #    echo rsync -av --keep-dirlinks ${ARCHDIR}/kvm-zyp-${REPONAME}-${ARCH}/ ./${REPONAME}-${ARCH}/
      #    ;;
      #  'sles12')
      #    if [ "${ARCH}" = "amd64" ]; then
      #      echo rsync -av --keep-dirlinks ${ARCHDIR}/kvm-zyp-${REPONAME}-${ARCH}/ ./${REPONAME}-${ARCH}/
      #    else
      #      echo "+ no packages for ${REPONAME}-${ARCH}"
      #    fi
      #    ;;
      #  *)
      #    echo rsync -av --keep-dirlinks ${ARCHDIR}/kvm-rpm-${REPONAME}-${ARCH}/ ./${REPONAME}-${ARCH}/
      #    ;;
      #esac

    done

    #-------------------------------------------------------------------------------
    # This next section, between 'set +u' and 'set -u' creates symlinks for
    # various rhel and centos minor versions (e.g. 'centos/6.4') back to the
    # major version directory (e.g. 'centos/6'). The first set command turns
    # off the behavior where unset variables are treated as errors, and the
    # second one turns it back on. Code between the set commands is indented to
    # help make things more readable.
    #-------------------------------------------------------------------------------
    set +u
      eval vers_min=\$vers_min_${distro}_${ver_maj}
      if [ "${vers_min}" != "" ]; then
        for ver_min in $(seq ${vers_min}); do
          ln -sv ${ver_maj} ${distro}/${ver_maj}.${ver_min}
        done
      fi
    set -u

    # Add in special RHEL links
    if [ "${distro}" = "rhel" ]; then
      ln -sv ${ver_maj} ${distro}/${ver_maj}Server
      ln -sv ${ver_maj} ${distro}/${ver_maj}Client
    fi

  done
done
#exit 0 # Ending here for testing

# Fix for CentOS/RHEL 7.3
if [[ "${ARCHDIR}" == *"5.5"* ]]; then
  echo "+ No 5.5 packages for CentOS/RHEL 7.3 yet"
else
  rm -v rhel/7.3
  mkdir -vp rhel/7.3/x86_64
  ln -sv rhel/7.3/x86_64 rhel73-amd64
fi


# Copy over the packages
for REPONAME in ${dists}; do
  for ARCH in ${architectures}; do
    case "${REPONAME}" in
      'rhel5')
        #mkdir -vp "${REPONAME}-${ARCH}"
        rsync -av --keep-dirlinks ${ARCHDIR}/kvm-rpm-centos5-${ARCH}/ ./${REPONAME}-${ARCH}/
        ;;
      'rhel6')
        #mkdir -vp "${REPONAME}-${ARCH}"
        rsync -av --keep-dirlinks ${ARCHDIR}/kvm-rpm-centos6-${ARCH}/ ./${REPONAME}-${ARCH}/
        ;;
      'centos7'|'rhel7')
        if [ "${ARCH}" = "amd64" ]; then
          #mkdir -vp "${REPONAME}-${ARCH}"
          rsync -av --keep-dirlinks ${ARCHDIR}/kvm-rpm-centos7-${ARCH}/ ./${REPONAME}-${ARCH}/
          if [[ "${ARCHDIR}" == *"5.5"* ]]; then
            echo "+ skipping rsync of 7.3 packages as they are not available for 5.5 yet"
          else
            rsync -av --keep-dirlinks ${ARCHDIR}/kvm-rpm-centos73-${ARCH}/ ./${REPONAME}3-${ARCH}/
          fi
        else
          echo "+ no packages for ${REPONAME}-${ARCH}"
        fi
        ;;
      'opensuse42')
        if [ "${ARCH}" = "amd64" ]; then
          rsync -av --keep-dirlinks ${ARCHDIR}/kvm-zyp-${REPONAME}-${ARCH}/ ./${REPONAME}-${ARCH}/
        else
          echo "+ no packages for ${REPONAME}-${ARCH}"
        fi
        ;;
      'opensuse13'|'sles11')
        #mkdir -vp "${REPONAME}-${ARCH}"
        if [ "${REPONAME}-${ARCH}" = "sles11-amd64" ]; then
          # We pull sles11-amd64 packages from the sles11sp1-amd64 builder
          #rsync -av --keep-dirlinks ${ARCHDIR}/kvm-zyp-${REPONAME}sp1-${ARCH}/ ./${REPONAME}-${ARCH}/

          # 2017-01-16 - we no longer pull from sp1 - dbart
          rsync -av --keep-dirlinks ${ARCHDIR}/kvm-zyp-${REPONAME}-${ARCH}/ ./${REPONAME}-${ARCH}/
        else
          rsync -av --keep-dirlinks ${ARCHDIR}/kvm-zyp-${REPONAME}-${ARCH}/ ./${REPONAME}-${ARCH}/
        fi
        ;;
      'sles12')
        if [ "${ARCH}" = "amd64" ]; then
          #mkdir -vp "${REPONAME}-${ARCH}"
          rsync -av --keep-dirlinks ${ARCHDIR}/kvm-zyp-${REPONAME}-${ARCH}/ ./${REPONAME}-${ARCH}/
        else
          echo "+ no packages for ${REPONAME}-${ARCH}"
        fi
        ;;
      *)
        #mkdir -vp "${REPONAME}-${ARCH}"
        rsync -av --keep-dirlinks ${ARCHDIR}/kvm-rpm-${REPONAME}-${ARCH}/ ./${REPONAME}-${ARCH}/
        ;;
    esac

      # Add in custom jemalloc packages for distros that need them
      case "${REPONAME}-${ARCH}" in
        'rhel5-amd64'|'rhel5-x86'|'rhel6-amd64'|'rhel6-x86'|'rhel6-ppc64'|'rhel7-amd64'|'rhel7-ppc64') 
          rsync -av --keep-dirlinks ${dir_jemalloc}/jemalloc-${REPONAME}-${ARCH}-${suffix}/*.rpm ./${REPONAME}-${ARCH}/rpms/
          if [ "${REPONAME}" = 'rhel7' ]; then
            # if $REPONAME is rhel7, don't forget rhel73
            if [[ "${ARCHDIR}" == *"5.5"* ]]; then
              echo "+ skipping rsync of 7.3 packages as they are not available for 5.5 yet"
            else
              rsync -av --keep-dirlinks ${dir_jemalloc}/jemalloc-${REPONAME}-${ARCH}-${suffix}/*.rpm ./${REPONAME}3-${ARCH}/rpms/
            fi
          fi
          ;;
        * ) echo "no custom jemalloc packages for ${REPONAME}-${ARCH}"
          ;;
      esac

      # Add in nmap where needed
      case "${REPONAME}-${ARCH}" in
        #'sles12-amd64'|'sles12-x86')
        'sles12-amd64')
          rsync -av --keep-dirlinks ${dir_nmap}/${ARCH}/${ver_nmap}-${suffix}/rpms/*.rpm ./${REPONAME}-${ARCH}/rpms/
          ;;
      esac

      # Copy in galera packages if requested
      if [ ${GALERA} = "yes" ]; then
        for gv in ${ver_galera}; do
          if [ "${ARCH}" = "amd64" ]; then
            if [ "${REPONAME}" = "centos5" ] || [ "${REPONAME}" = "rhel5" ]; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*rhel5*x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "centos7" ] || [ "${REPONAME}" = "rhel7" ]; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*rhel7*x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
              if [[ "${ARCHDIR}" == *"5.5"* ]]; then
                echo "+ No 5.5 packages for CentOS/RHEL 7.3 yet"
              else
                rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*rhel7*x86_64.rpm ./${REPONAME}3-${ARCH}/rpms/
              fi
            elif [ "${REPONAME}" = "fedora19" ] ; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*fc19*x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora20" ] ; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*fc20*x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora21" ] ; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*fc21*x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora22" ] ; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*fc22*x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora23" ] ; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*fc23*x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora24" ] ; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*fc24*x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora25" ] ; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*fc25*x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "sles11" ] ; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*sles11*x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "sles12" ] ; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*sles12*x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "opensuse13" ] ; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*sles13*x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "opensuse42" ] ; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*sles42*x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            else
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*rhel6*x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            fi
          else
            if [ "${REPONAME}" = "centos5" ] || [ "${REPONAME}" = "rhel5" ]; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*rhel5*i386.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora19" ] ; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*fc19*i386.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora20" ] ; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*fc20*i686.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora21" ] ; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*fc21*i686.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora22" ] ; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*fc22*i686.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora23" ] ; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*fc23*i686.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora24" ] ; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*fc24*i686.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora25" ] ; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*fc25*i686.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "sles11" ] ; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*sles11*i586.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "opensuse42" ] ; then
              echo "+ no packages for ${REPONAME}-${ARCH}"
            elif [ "${REPONAME}" = "opensuse13" ] ; then
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*sles13*i586.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "sles12" ] || [ "${REPONAME}" = "centos7" ] || [ "${REPONAME}" = "rhel7" ]; then
              echo "+ no packages for ${REPONAME}-${ARCH}"
            else
              rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*rhel6*i*86.rpm ./${REPONAME}-${ARCH}/rpms/
            fi
          fi
        done
      fi
  done
done




#if [ "${ENTERPRISE}" = "yes" ]; then
  for P8_REPONAME in ${p8_dists}; do
    for P8_ARCH in ${p8_architectures}; do
        if [ "${P8_REPONAME}" = "rhel6" ]; then
          if [ "${P8_ARCH}" = "ppc64" ]; then
            #mkdir -vp "${P8_REPONAME}-${P8_ARCH}"
            mkdir -v rhel/6/${P8_ARCH}
            ln -sv rhel/6/${P8_ARCH} ./${P8_REPONAME}-${P8_ARCH}
            rsync -av --keep-dirlinks ${P8_ARCHDIR}/p8-rhel6-rpm/ ./${P8_REPONAME}-${P8_ARCH}/
          else
            echo "+ no packages for ${P8_REPONAME}-${P8_ARCH}"
          fi
        elif [ "${P8_REPONAME}" = "centos71" ] || [ "${P8_REPONAME}" = "rhel71" ]; then
          if [ "${P8_ARCH}" = "ppc64le" ]; then
            #mkdir -vp "${P8_REPONAME}-${P8_ARCH}"
            mkdir -v rhel/7/${P8_ARCH}
            ln -sv rhel/7/${P8_ARCH} ./rhel7-${P8_ARCH}
            rsync -av --keep-dirlinks ${P8_ARCHDIR}/p8-rhel71-rpm/ ./rhel7-${P8_ARCH}/
          else
            echo "+ no packages for ${P8_REPONAME}-${P8_ARCH}"
          fi
        elif [ "${P8_REPONAME}" = "centos7" ] || [ "${P8_REPONAME}" = "rhel7" ]; then
          if [ "${P8_ARCH}" = "ppc64" ]; then
            #mkdir -vp "${P8_REPONAME}-${P8_ARCH}"
            mkdir -v rhel/7/${P8_ARCH}
            ln -sv rhel/7/${P8_ARCH} ./${P8_REPONAME}-${P8_ARCH}
            rsync -av --keep-dirlinks ${P8_ARCHDIR}/p8-rhel7-rpm/ ./${P8_REPONAME}-${P8_ARCH}/
          else
            echo "+ no packages for ${P8_REPONAME}-${P8_ARCH}"
          fi
        elif [ "${P8_REPONAME}" = "sles12" ]; then
          if [ "${P8_ARCH}" = "ppc64le" ]; then
            #mkdir -vp "${P8_REPONAME}-${P8_ARCH}"
            mkdir -v sles/12/${P8_ARCH}
            ln -sv sles/12/${P8_ARCH} ./${P8_REPONAME}-${P8_ARCH}
            rsync -av --keep-dirlinks ${P8_ARCHDIR}/p8-suse12-rpm/ ./${P8_REPONAME}-${P8_ARCH}/
          else
            echo "+ no packages for ${P8_REPONAME}-${P8_ARCH}"
          fi
        elif [ "${P8_REPONAME}" = "rhel73" ]; then
          mkdir -v rhel/7.3/${P8_ARCH}
          ln -sv rhel/7.3/${P8_ARCH} ./${P8_REPONAME}-${P8_ARCH}
          rsync -av --keep-dirlinks ${ARCHDIR}/kvm-rpm-centos73-${P8_ARCH}/ ./${P8_REPONAME}-${P8_ARCH}/
        fi
  
        # Add in custom jemalloc packages for distros that need them
        case "${P8_REPONAME}-${P8_ARCH}" in
          'centos7-ppc64'|'rhel7-ppc64'|'centos6-ppc64'|'rhel6-ppc64')
            rsync -av --keep-dirlinks ${dir_jemalloc}/jemalloc-${P8_REPONAME}-${P8_ARCH}-${suffix}/*.rpm ./${P8_REPONAME}-${P8_ARCH}/rpms/
            ;;
          * ) 
            echo "no custom jemalloc packages for ${P8_REPONAME}-${P8_ARCH}"
            ;;
        esac
  
        # Add galera packages for enterprise cluster  
        case "${P8_REPONAME}-${P8_ARCH}" in
          'rhel6-ppc64')
            rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*rhel6*ppc64.rpm ./${P8_REPONAME}-${P8_ARCH}/rpms/ 
            ;;
          'rhel7-ppc64')
            rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*rhel7*ppc64.rpm ./${P8_REPONAME}-${P8_ARCH}/rpms/ 
            ;;
          'sles12-ppc64le')
            rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*sles12*ppc64le.rpm ./${P8_REPONAME}-${P8_ARCH}/rpms/
            ;; 
          'rhel71-ppc64le')
            rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/*rhel7*ppc64le.rpm ./rhel7-${P8_ARCH}/rpms/
            ;; 
          'rhel73-ppc64')
            rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/centos73/*rhel7*ppc64.rpm ./${P8_REPONAME}-${P8_ARCH}/rpms/ 
            ;;
          'rhel73-ppc64le')
            rsync -av --keep-dirlinks ${dir_galera}/galera-${gv}-${suffix}/rpm/centos73/*rhel7*ppc64le.rpm ./${P8_REPONAME}-${P8_ARCH}/rpms/ 
            ;;
          * )
            echo "no galera packages found for enterprise cluster release"
            ;;
        esac
   
        # Add in advance-toolchain runtime for distros that need them
        case "${P8_REPONAME}-${P8_ARCH}" in
          'centos6-ppc64'|'rhel6-ppc64'|'centos7-ppc64'|'rhel7-ppc64'|'sles12-ppc64le')
            rsync -av --keep-dirlinks ${dir_at}/${P8_REPONAME}-${P8_ARCH}-${suffix}/*runtime*.rpm ./${P8_REPONAME}-${P8_ARCH}/rpms/
            ;;
          'centos71-ppc64le'|'rhel71-ppc64le')
            rsync -av --keep-dirlinks ${dir_at}/${P8_REPONAME}-${P8_ARCH}-${suffix}/*runtime*.rpm ./rhel7-${P8_ARCH}/rpms/
            ;;
          * ) 
            echo "no advance-toolchain packages for ${P8_REPONAME}-${P8_ARCH}"
            ;;
        esac
  
    done
  done
#fi

# Sign all the rpms with the appropriate key
rpmsign --addsign --key-id=${gpg_key} $(find . -name '*.rpm')

for DIR in *-*; do
  if [ -d "${DIR}" ]; then
    # regenerate the md5sums.txt file (signing packages changes their checksum)
    cd ${DIR}
    pwd
    if [ -e md5sums.txt ]; then rm -v md5sums.txt ; fi
    md5sum $(find . -name '*.rpm') >> md5sums.txt
    md5sum -c md5sums.txt

    if [ -e sha1sums.txt ]; then rm -v sha1sums.txt ; fi
    sha1sum $(find . -name '*.rpm') >> sha1sums.txt
    sha1sum -c sha1sums.txt

    if [ -e sha256sums.txt ]; then rm -v sha256sums.txt ; fi
    sha256sum $(find . -name '*.rpm') >> sha256sums.txt
    sha256sum -c sha256sums.txt

    if [ -e sha512sums.txt ]; then rm -v sha512sums.txt ; fi
    sha512sum $(find . -name '*.rpm') >> sha512sums.txt
    sha512sum -c sha512sums.txt

    cd ..

    # Create the repository and sign the repomd.xml file
    case ${DIR} in
      'centos5-amd64'|'centos5-x86'|'rhel5-amd64'|'rhel5-x86'|'sles11-amd64'|'sles11-x86')
        # CentOS & RHEL 5 don't support newer sha256 checksums
        createrepo -s sha --database --pretty ${DIR}
        ;;
      *)
        createrepo --database --pretty ${DIR}
        ;;
    esac
    
    gpg2 --detach-sign --armor -u ${gpg_key} ${DIR}/repodata/repomd.xml 

    # Add a README to the srpms directory
    mkdir -vp ${DIR}/srpms
    echo "Why do MariaDB RPMs not include the source RPM (SRPMS)?
https://mariadb.com/kb/en/why-do-mariadb-rpms-not-include-the-source-rpm-srpms
" > ${DIR}/srpms/README
  fi
done

# create a symlink from the sles11-amd64 dir to a dir named after the sp1
# builder (this is done so buildbot tests work)
#ln -sv sles11-amd64 sles11sp1-amd64

# add in links from rhel dirs to equivalent centos dirs
ln -sv rhel centos

if [ -e "rhel5-x86"     ]; then ln -sv rhel5-x86     centos5-x86     ;fi
if [ -e "rhel5-amd64"   ]; then ln -sv rhel5-amd64   centos5-amd64   ;fi

if [ -e "rhel6-x86"     ]; then ln -sv rhel6-x86     centos6-x86     ;fi
if [ -e "rhel6-amd64"   ]; then ln -sv rhel6-amd64   centos6-amd64   ;fi
if [ -e "rhel6-ppc64"   ]; then ln -sv rhel6-ppc64   centos6-ppc64   ;fi

if [ -e "rhel7-amd64"   ]; then ln -sv rhel7-amd64   centos7-amd64   ;fi
if [ -e "rhel7-ppc64"   ]; then ln -sv rhel7-ppc64   centos7-ppc64   ;fi
if [ -e "rhel7-ppc64le" ]; then ln -sv rhel7-ppc64le centos7-ppc64le ;fi

if [ -e "rhel73-amd64"   ]; then ln -sv rhel73-amd64   centos73-amd64   ;fi
if [ -e "rhel73-ppc64"   ]; then ln -sv rhel73-ppc64   centos73-ppc64   ;fi
if [ -e "rhel73-ppc64le" ]; then ln -sv rhel73-ppc64le centos73-ppc64le ;fi

# vim: filetype=sh
