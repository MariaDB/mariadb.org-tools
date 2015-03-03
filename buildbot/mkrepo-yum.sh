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
galera_versions="25.3.5"                          # Version of galera in repos
galera_dir="/ds413/galera"                        # Location of galera pkgs
jemalloc_dir="/ds413/vms-customizations/jemalloc" # Location of jemalloc pkgs
at_dir="/ds413/vms-customizations/advance-toolchain/" # Location of at pkgs
architectures="amd64 x86"
dists="sles11 sles12 opensuse13 centos5 rhel5 centos6 rhel6 centos7 rhel7 fedora19 fedora20"
#dists="opensuse13 centos5 rhel5 centos6 rhel6 centos7 rhel7 fedora19 fedora20"
#dists="opensuse13 centos7 rhel7"
#dists="centos5 rhel5"

if [ "${ENTERPRISE}" = "yes" ]; then
  p8_dists="rhel6 rhel7 rhel71 sles12"
  p8_architectures="ppc64 ppc64le"
  #gpg_key="0xd324876ebe6a595f"               # original enterprise key
  gpg_key="0xce1a3dd5e3c94f49"                # new enterprise key (2014-12-18)
  suffix="signed-ent"
else
  gpg_key="0xcbcb082a1bb943db"                 # mariadb.org signing key
  suffix="signed"
fi

#-------------------------------------------------------------------------------
#  Main Script
#-------------------------------------------------------------------------------
# Get the GPG daemon running so we don't have to keep entering the password for
# the GPG key every time we sign a package
eval $(gpg-agent --daemon)

# At this point, all variables should be set. Print a usage message if the
# ${ARCHDIR} variable is not set (the last of the command-line variables).
if [ ! -d "$ARCHDIR" ] ; then
    echo 1>&2 "Usage: $0 <galera?> <enterprise?> <archive directory>"
    echo 1>&2 "For <galera?> and <enterprise?> : yes or no"
    exit 1
fi

# After this point, we tread unset variables as an error
set -u
  # -u  Treat unset variables as an error when performing parameter expansion.
  #     An error message will be written to the standard error, and a
  #     non-interactive shell will exit.

# Copy over the packages
for REPONAME in ${dists}; do
  for ARCH in ${architectures}; do
    # the following 3 line if/else block is a dirty fix for a release, comment
    # out after the release, and the line with the "# End of dirty fix" comment
    #if [ "${REPONAME}-${ARCH}" = "centos6-x86" ] || [ "${REPONAME}-${ARCH}" = "rhel6-x86" ]; then
    #  echo "Skipping ${REPONAME}=${ARCH}..."
    #else
    case "${REPONAME}" in
      'rhel6')
        mkdir -vp "${REPONAME}-${ARCH}"
        rsync -avP ${ARCHDIR}/kvm-rpm-centos6-${ARCH}/ ./${REPONAME}-${ARCH}/
        ;;
      'centos7'|'rhel7')
        if [ "${ARCH}" = "amd64" ]; then
          mkdir -vp "${REPONAME}-${ARCH}"
          rsync -avP ${ARCHDIR}/kvm-rpm-centos7-${ARCH}/ ./${REPONAME}-${ARCH}/
        else
          echo "+ no packages for ${REPONAME}-${ARCH}"
        fi
        ;;
      'opensuse13'|'sles11')
        mkdir -vp "${REPONAME}-${ARCH}"
        rsync -avP ${ARCHDIR}/kvm-zyp-${REPONAME}-${ARCH}/ ./${REPONAME}-${ARCH}/
        ;;
      'sles12')
        if [ "${ARCH}" = "amd64" ]; then
          mkdir -vp "${REPONAME}-${ARCH}"
          rsync -avP ${ARCHDIR}/kvm-zyp-${REPONAME}-${ARCH}/ ./${REPONAME}-${ARCH}/
        else
          echo "+ no packages for ${REPONAME}-${ARCH}"
        fi
        ;;
      *)
        mkdir -vp "${REPONAME}-${ARCH}"
        rsync -avP ${ARCHDIR}/kvm-rpm-${REPONAME}-${ARCH}/ ./${REPONAME}-${ARCH}/
        ;;
    esac

      #if [ "${REPONAME}" = "rhel6" ]; then
      #  mkdir -vp "${REPONAME}-${ARCH}"
      #  rsync -avP ${ARCHDIR}/kvm-rpm-centos6-${ARCH}/ ./${REPONAME}-${ARCH}/
      ### tmp fix for broken rhel5-x86 builds
      ##elif [ "${REPONAME}" = "rhel5" ]; then
      ##  if [ "${ARCH}" = "x86" ]; then
      ##    cp -avi ${ARCHDIR}/kvm-rpm-centos5-${ARCH}/* ./${REPONAME}-${ARCH}/
      ##  else
      ##    cp -avi ${ARCHDIR}/kvm-rpm-${REPONAME}-${ARCH}/* ./${REPONAME}-${ARCH}/
      ##  fi
      ### end of tmp fix for broken rhel5-x86 builds
      #elif [ "${REPONAME}" = "centos7" ] || [ "${REPONAME}" = "rhel7" ]; then
      #  if [ "${ARCH}" = "amd64" ]; then
      #    mkdir -vp "${REPONAME}-${ARCH}"
      #    rsync -avP ${ARCHDIR}/kvm-rpm-centos7_0-x86_64/ ./${REPONAME}-${ARCH}/
      #  else
      #    echo "+ no packages for ${REPONAME}-${ARCH}"
      #  fi
      #elif [ "${REPONAME}" = "opensuse13" ]; then
      #  if [ "${ARCH}" = "amd64" ]; then
      #    mkdir -vp "${REPONAME}-${ARCH}"
      #    rsync -avP ${ARCHDIR}/kvm-zyp-opensuse13_1-x86_64/ ./${REPONAME}-${ARCH}/
      #  else
      #    mkdir -vp "${REPONAME}-${ARCH}"
      #    rsync -avP ${ARCHDIR}/kvm-zyp-opensuse13_1-x86/ ./${REPONAME}-${ARCH}/
      #  fi
      #else
      #  mkdir -vp "${REPONAME}-${ARCH}"
      #  rsync -avP ${ARCHDIR}/kvm-rpm-${REPONAME}-${ARCH}/ ./${REPONAME}-${ARCH}/
      #fi

      # Add in custom jemalloc packages for distros that need them
      case "${REPONAME}-${ARCH}" in
        'opensuse13-x86'|'opensuse13-amd64'|'sles11-x86'|'sles11-amd64'|'sles12-amd64'|'sles12-x86')
          echo "no custom jemalloc packages for ${REPONAME}-${ARCH}"
          ;;
        'centos7-x86'|'rhel7-x86'|'fedora19-x86'|'fedora19-amd64'|'fedora20-x86'|'fedora20-amd64')
          echo "no custom jemalloc packages for ${REPONAME}-${ARCH}"
          ;;
        * ) rsync -avP ${jemalloc_dir}/jemalloc-${REPONAME}-${ARCH}-${suffix}/*.rpm ./${REPONAME}-${ARCH}/rpms/
          ;;
      esac

      # Copy in galera packages if requested
      if [ ${GALERA} = "yes" ]; then
        for gv in ${galera_versions}; do
          if [ "${ARCH}" = "amd64" ]; then
            if [ "${REPONAME}" = "centos5" ] || [ "${REPONAME}" = "rhel5" ]; then
              rsync -avP ${galera_dir}/galera-${gv}-${suffix}/*rhel5.x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora17" ] ; then
              rsync -avP ${galera_dir}/galera-${gv}-${suffix}/*fc17.x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora18" ] ; then
              rsync -avP ${galera_dir}/galera-${gv}-${suffix}/*fc18.x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora19" ] ; then
              rsync -avP ${galera_dir}/galera-${gv}-${suffix}/*fc19.x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora20" ] ; then
              rsync -avP ${galera_dir}/galera-${gv}-${suffix}/*fc20.x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "sles11" ] ; then
              rsync -avP ${galera_dir}/galera-${gv}-${suffix}/*sles11.x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "sles12" ] ; then
              rsync -avP ${galera_dir}/galera-${gv}-${suffix}/*sles12.x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            else
              rsync -avP ${galera_dir}/galera-${gv}-${suffix}/*rhel6.x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            fi
          else
            if [ "${REPONAME}" = "centos5" ] || [ "${REPONAME}" = "rhel5" ]; then
              rsync -avP  ${galera_dir}/galera-${gv}-${suffix}/*rhel5.i386.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora17" ] ; then
              rsync -avP ${galera_dir}/galera-${gv}-${suffix}/*fc17.i686.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora18" ] ; then
              rsync -avP ${galera_dir}/galera-${gv}-${suffix}/*fc18.i686.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora19" ] ; then
              rsync -avP ${galera_dir}/galera-${gv}-${suffix}/*fc19.i386.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora20" ] ; then
              rsync -avP ${galera_dir}/galera-${gv}-${suffix}/*fc20.i686.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "sles11" ] ; then
              rsync -avP ${galera_dir}/galera-${gv}-${suffix}/*sles11.i586.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "sles12" ] || [ "${REPONAME}" = "opensuse13" ] || [ "${REPONAME}" = "centos7" ] || [ "${REPONAME}" = "rhel7" ]; then
              echo "+ no packages for ${REPONAME}-${ARCH}"
            else
              rsync -avP  ${galera_dir}/galera-${gv}-${suffix}/*rhel6.i*86.rpm ./${REPONAME}-${ARCH}/rpms/
            fi
          fi
        done
      fi
    #fi # End of dirty fix
  done
done




if [ "${ENTERPRISE}" = "yes" ]; then
  for P8_REPONAME in ${p8_dists}; do
    for P8_ARCH in ${p8_architectures}; do
        if [ "${P8_REPONAME}" = "rhel6" ]; then
          if [ "${P8_ARCH}" = "ppc64" ]; then
            mkdir -vp "${P8_REPONAME}-${P8_ARCH}"
            rsync -avP ${P8_ARCHDIR}/p8-rhel6-rpm/ ./${P8_REPONAME}-${P8_ARCH}/
          else
            echo "+ no packages for ${P8_REPONAME}-${P8_ARCH}"
          fi
        elif [ "${P8_REPONAME}" = "centos71" ] || [ "${P8_REPONAME}" = "rhel71" ]; then
          if [ "${P8_ARCH}" = "ppc64le" ]; then
            mkdir -vp "${P8_REPONAME}-${P8_ARCH}"
            rsync -avP ${P8_ARCHDIR}/p8-rhel71-rpm/ ./${P8_REPONAME}-${P8_ARCH}/
          else
            echo "+ no packages for ${P8_REPONAME}-${P8_ARCH}"
          fi
        elif [ "${P8_REPONAME}" = "centos7" ] || [ "${P8_REPONAME}" = "rhel7" ]; then
          if [ "${P8_ARCH}" = "ppc64" ]; then
            mkdir -vp "${P8_REPONAME}-${P8_ARCH}"
            rsync -avP ${P8_ARCHDIR}/p8-rhel7-rpm/ ./${P8_REPONAME}-${P8_ARCH}/
          else
            echo "+ no packages for ${P8_REPONAME}-${P8_ARCH}"
          fi
        elif [ "${P8_REPONAME}" = "sles12" ]; then
          if [ "${P8_ARCH}" = "ppc64le" ]; then
            mkdir -vp "${P8_REPONAME}-${P8_ARCH}"
            rsync -avP ${P8_ARCHDIR}/p8-suse12-rpm/ ./${P8_REPONAME}-${P8_ARCH}/
          else
            echo "+ no packages for ${P8_REPONAME}-${P8_ARCH}"
          fi
        fi

        # Add in custom jemalloc packages for distros that need them
        case "${P8_REPONAME}-${P8_ARCH}" in
          'centos7-ppc64'|'rhel7-ppc64'|'centos6-ppc64'|'rhel6-ppc64')
            rsync -avP ${jemalloc_dir}/jemalloc-${P8_REPONAME}-${P8_ARCH}-${suffix}/*.rpm ./${P8_REPONAME}-${P8_ARCH}/rpms/
            ;;
          * ) 
            echo "no custom jemalloc packages for ${P8_REPONAME}-${P8_ARCH}"
            ;;
        esac

        # Add in advance-toolchain runtime for distros that need them
        case "${P8_REPONAME}-${P8_ARCH}" in
          'centos6-ppc64'|'rhel6-ppc64'|'centos7-ppc64'|'rhel7-ppc64'|'centos71-ppc64le'|'rhel71-ppc64le'|'sles12-ppc64le')
            rsync -avP ${at_dir}/${P8_REPONAME}-${P8_ARCH}-${suffix}/*runtime*.rpm ./${P8_REPONAME}-${P8_ARCH}/rpms/
            ;;
          * ) 
            echo "no advance-toolchain packages for ${P8_REPONAME}-${P8_ARCH}"
            ;;
        esac


        # Copy in galera packages if requested
        #if [ ${GALERA} = "yes" ]; then
        #  for gv in ${galera_versions}; do
        #    if [ "${P8_ARCH}" = "amd64" ]; then
        #      if [ "${P8_REPONAME}" = "centos5" ] || [ "${P8_REPONAME}" = "rhel5" ]; then
        #        rsync -avP ${galera_dir}/galera-${gv}/*rhel5.x86_64.rpm ./${P8_REPONAME}-${P8_ARCH}/rpms/
        #      elif [ "${P8_REPONAME}" = "fedora17" ] ; then
        #        rsync -avP ${galera_dir}/galera-${gv}/*fc17.x86_64.rpm ./${P8_REPONAME}-${P8_ARCH}/rpms/
        #      elif [ "${P8_REPONAME}" = "fedora18" ] ; then
        #        rsync -avP ${galera_dir}/galera-${gv}/*fc18.x86_64.rpm ./${P8_REPONAME}-${P8_ARCH}/rpms/
        #      elif [ "${P8_REPONAME}" = "fedora19" ] ; then
        #        rsync -avP ${galera_dir}/galera-${gv}/*fc19.x86_64.rpm ./${P8_REPONAME}-${P8_ARCH}/rpms/
        #      elif [ "${P8_REPONAME}" = "fedora20" ] ; then
        #        rsync -avP ${galera_dir}/galera-${gv}/*fc20.x86_64.rpm ./${P8_REPONAME}-${P8_ARCH}/rpms/
        #      else
        #        rsync -avP ${galera_dir}/galera-${gv}/*rhel6.x86_64.rpm ./${P8_REPONAME}-${P8_ARCH}/rpms/
        #      fi
        #    else
        #      if [ "${P8_REPONAME}" = "centos5" ] || [ "${P8_REPONAME}" = "rhel5" ]; then
        #        rsync -avP  ${galera_dir}/galera-${gv}/*rhel5.i386.rpm ./${P8_REPONAME}-${P8_ARCH}/rpms/
        #      elif [ "${P8_REPONAME}" = "fedora17" ] ; then
        #        rsync -avP ${galera_dir}/galera-${gv}/*fc17.i686.rpm ./${P8_REPONAME}-${P8_ARCH}/rpms/
        #      elif [ "${P8_REPONAME}" = "fedora18" ] ; then
        #        rsync -avP ${galera_dir}/galera-${gv}/*fc18.i686.rpm ./${P8_REPONAME}-${P8_ARCH}/rpms/
        #      elif [ "${P8_REPONAME}" = "fedora19" ] ; then
        #        rsync -avP ${galera_dir}/galera-${gv}/*fc19.i386.rpm ./${P8_REPONAME}-${P8_ARCH}/rpms/
        #      elif [ "${P8_REPONAME}" = "fedora20" ] ; then
        #        rsync -avP ${galera_dir}/galera-${gv}/*fc20.i686.rpm ./${P8_REPONAME}-${P8_ARCH}/rpms/
        #      elif [ "${P8_REPONAME}" = "opensuse13" ] || [ "${P8_REPONAME}" = "centos7" ] || [ "${P8_REPONAME}" = "rhel7" ]; then
        #        echo "+ no packages for ${P8_REPONAME}-${P8_ARCH}"
        #      else
        #        rsync -avP  ${galera_dir}/galera-${gv}/*rhel6.i*86.rpm ./${P8_REPONAME}-${P8_ARCH}/rpms/
        #      fi
        #    fi
        #  done
        #fi
    done
  done
fi

# Sign all the rpms with the appropriate key
rpmsign --addsign --key-id=${gpg_key} $(find . -name '*.rpm')

#cur_dir=$(pwd)
#
#  for dir in * ; do
#    ls
#    cd ${dir}
#    case ${dir} in 
#      'centos5-amd64'|'centos5-x86'|'rhel5-amd64'|'rhel5-x86')
#        if [ "${ENTERPRISE}" = "yes" ]; then
#          rpmsign --addsign --key-id=${gpg_key_v2} $(find . -name '*.rpm')
#          echo "is enterprise"
#        else
#          rpmsign --addsign --key-id=${gpg_key} $(find . -name '*.rpm')
#        fi
#        echo "is rhel5/centos5!"
#        ;;
#      *)
#        rpmsign --addsign --key-id=${gpg_key} $(find . -name '*.rpm')
#        ;;
#    esac
#    echo changing dir
#    cd ${cur_dir}
#  done
#

#  for dir in * ; do
#    cd ${dir}
#    case ${dir} in 
#      'centos5-amd64'|'centos5-x86'|'rhel5-amd64'|'rhel5-x86')
#        if [ "${ENTERPRISE}" = "yes" ]; then
#          rpmsign --macros="/usr/lib/rpm/macros:~/.rpmmacros-ent-v3" --addsign --key-id=${gpg_key} $(find . -name '*.rpm')
#        else
#          rpmsign --macros="/usr/lib/rpm/macros:~/.rpmmacros-v3" --addsign --key-id=${gpg_key} $(find . -name '*.rpm')
#        fi
#        ;;
#      *)
#        if [ "${ENTERPRISE}" = "yes" ]; then
#          rpmsign --macros="/usr/lib/rpm/macros:~/.rpmmacros-ent" --addsign --key-id=${gpg_key} $(find . -name '*.rpm')
#        else
#          rpmsign --addsign --key-id=${gpg_key} $(find . -name '*.rpm')
#        fi
#        ;;
#    esac
#    cd ${cur_dir}
#  done
#

#if [ "${ENTERPRISE}" = "yes" ]; then
#  rpmsign --addsign --key-id=0xd324876ebe6a595f $(find . -name '*.rpm')
#else
#  rpmsign --addsign --key-id=0xcbcb082a1bb943db $(find . -name '*.rpm')
#fi

for DIR in *; do
  if [ -d "${DIR}" ]; then
    # regenerate the md5sums.txt file (signing the packages changes their checksum)
    cd ${DIR}
    pwd
    rm -v md5sums.txt
    md5sum $(find . -name '*.rpm') >> md5sums.txt
    md5sum -c md5sums.txt
    cd ..

    # Create the repository and sign the repomd.xml file
    case ${DIR} in
      'centos5-amd64'|'centos5-x86'|'rhel5-amd64'|'rhel5-x86')
        # CentOS & RHEL 5 don't support newer sha256 checksums
        createrepo --no-database -s sha --database --pretty ${DIR}
        ;;
      *)
        createrepo --database --pretty ${DIR}
        ;;
    esac
    
    gpg --detach-sign --armor -u ${gpg_key} ${DIR}/repodata/repomd.xml 

    #case ${DIR} in 
    #  'centos5-amd64'|'centos5-x86'|'rhel5-amd64'|'rhel5-x86')
    #    if [ "${ENTERPRISE}" = "yes" ]; then
    #      gpg --detach-sign --armor -u ${gpg_key_v2} ${DIR}/repodata/repomd.xml 
    #    else
    #      gpg --detach-sign --armor -u ${gpg_key} ${DIR}/repodata/repomd.xml 
    #    fi
    #    ;;
    #  *)
    #    gpg --detach-sign --armor -u ${gpg_key} ${DIR}/repodata/repomd.xml 
    #    ;;
    #esac

    # Add a README to the srpms directory
    mkdir -vp ${DIR}/srpms
    echo "Why do MariaDB RPMs not include the source RPM (SRPMS)?
https://mariadb.com/kb/en/why-do-mariadb-rpms-not-include-the-source-rpm-srpms
" > ${DIR}/srpms/README
  fi
done

#for REPONAME in ${dists}; do
#  for ARCH in ${architectures}; do
#    case "${REPONAME}-${ARCH}" in
#      "opensuse13-x86"|"centos7-x86"|"rhel7-x86")
#        echo "+ no packages for ${REPONAME}-${ARCH}"
#        ;;
#      *)
#        cd ${REPONAME}-${ARCH};
#        pwd
#        rm -v md5sums.txt
#        md5sum $(find . -name '*.rpm') >> md5sums.txt
#        md5sum -c md5sums.txt
#        cd ..
#        ;;
#    esac
#  done
#done

# Here is where we actually create the YUM repositories for each distribution
# and sign the repomd.xml file
#for REPONAME in ${dists}; do
#  for ARCH in ${architectures}; do
#    if [ "${REPONAME}-${ARCH}" = "opensuse13-x86" ] || [ "${REPONAME}-${ARCH}" = "centos7-x86" ] || [ "${REPONAME}-${ARCH}" = "rhel7-x86" ]; then
#      echo "+ no packages for ${REPONAME}-${ARCH}"
#    else
#      createrepo --database --pretty ${REPONAME}-${ARCH}
#      # If this is an "Enterprise" MariaDB release, sign with the mariadb.com key,
#      # otherwise, sign with the mariadb.org key
#      if [ "${ENTERPRISE}" = "yes" ]; then
#        gpg --detach-sign --armor -u 0xd324876ebe6a595f ${REPONAME}-${ARCH}/repodata/repomd.xml 
#      else
#        gpg --detach-sign --armor -u 0xcbcb082a1bb943db ${REPONAME}-${ARCH}/repodata/repomd.xml 
#      fi
#    fi
#  done
#done

# Add in a README for the srpms directory
#for REPONAME in ${dists}; do
#  for ARCH in ${architectures}; do
#    if [ "${REPONAME}-${ARCH}" = "opensuse13-x86" ] || [ "${REPONAME}-${ARCH}" = "centos7-x86" ] || [ "${REPONAME}-${ARCH}" = "rhel7-x86" ]; then
#      echo "+ no packages for ${REPONAME}-${ARCH}"
#    else
#      mkdir -vp ${REPONAME}-${ARCH}/srpms
#      echo "Why do MariaDB RPMs not include the source RPM (SRPMS)?
#https://mariadb.com/kb/en/why-do-mariadb-rpms-not-include-the-source-rpm-srpms
#" >> ${REPONAME}-${ARCH}/srpms/README
#    fi
#  done
#done

# vim: filetype=sh
