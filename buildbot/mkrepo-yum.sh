#!/bin/bash - 
#===============================================================================
#
#          FILE:  mkrepo-yum.sh
# 
#         USAGE:  ./mkrepo-yum.sh <archive directory>
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

set -eux

eval $(gpg-agent --daemon)

GALERA="$1"                       # copy in galera packages? 'yes' or 'no'
ENTERPRISE="$2"                   # is this an enterprise release? 'yes' or 'no'
ARCHDIR="$3"                      # path to the packages

jemalloc_dir="/home/dbart/jemalloc"

dists="centos5 rhel5 centos6 rhel6 centos7 rhel7 fedora19 fedora20"
#dists="centos5 rhel5 centos6 rhel6 fedora18 fedora19 fedora20"
#dists="centos5 rhel5 centos6 rhel6 fedora17 fedora18 fedora19"
#dists="centos5 rhel5 centos6 fedora17 fedora18"
#dists="centos5 centos6 fedora17 fedora18"

galera_versions="25.3.5"
#galera_versions="25.3.5 25.2.9"
#galera_versions="25.3.2 25.2.8"
#galera_versions="25.3.2"

if [ ! -d "$ARCHDIR" ] ; then
    echo 1>&2 "Usage: $0 <galera?> <enterprise?> <archive directory>"
    echo 1>&2 "For <galera?> and <enterprise?> : yes or no"
    exit 1
fi

# Copy over the packages
#for REPONAME in centos5 rhel5; do
for REPONAME in ${dists}; do
  for ARCH in amd64 x86; do
    # the following 3 line if/else block is a dirty fix for a release, comment
    # out after the release, and the line with the "# End of dirty fix" comment
    #if [ "${REPONAME}-${ARCH}" = "centos6-x86" ] || [ "${REPONAME}-${ARCH}" = "rhel6-x86" ]; then
    #  echo "Skipping ${REPONAME}=${ARCH}..."
    #else
      #cp -avi ${ARCHDIR}/kvm-rpm-${REPONAME}-${ARCH}/* ./${REPONAME}-${ARCH}/

      if [ "${REPONAME}" = "rhel6" ]; then
        mkdir -vp "${REPONAME}-${ARCH}"
        rsync -avP ${ARCHDIR}/kvm-rpm-centos6-${ARCH}/ ./${REPONAME}-${ARCH}/
      ## tmp fix for broken rhel5-x86 builds
      #elif [ "${REPONAME}" = "rhel5" ]; then
      #  if [ "${ARCH}" = "x86" ]; then
      #    cp -avi ${ARCHDIR}/kvm-rpm-centos5-${ARCH}/* ./${REPONAME}-${ARCH}/
      #  else
      #    cp -avi ${ARCHDIR}/kvm-rpm-${REPONAME}-${ARCH}/* ./${REPONAME}-${ARCH}/
      #  fi
      ## end of tmp fix for broken rhel5-x86 builds
      elif [ "${REPONAME}" = "centos7" ] || [ "${REPONAME}" = "rhel7" ]; then
        if [ "${ARCH}" = "amd64" ]; then
          mkdir -vp "${REPONAME}-${ARCH}"
          rsync -avP ${ARCHDIR}/kvm-rpm-centos7_0-x86_64/ ./${REPONAME}-${ARCH}/
        else
          echo "+ no packages for ${REPONAME}-${ARCH}"
        fi
      else
        mkdir -vp "${REPONAME}-${ARCH}"
        rsync -avP ${ARCHDIR}/kvm-rpm-${REPONAME}-${ARCH}/ ./${REPONAME}-${ARCH}/
      fi

      # Copy in the jemalloc packages
      case "${REPONAME}-${ARCH}" in
        'centos7-x86'|'rhel7-x86'|'fedora19-x86'|'fedora19-amd64'|'fedora20-x86'|'fedora20-amd64')
          echo "no custom jemalloc packages for ${REPONAME}-${ARCH}"
          ;;
        * ) rsync -avP ${jemalloc_dir}/jemalloc-${REPONAME}-${ARCH}/*.rpm ./${REPONAME}-${ARCH}/rpms/
          ;;
      esac

      # Copy in the Galera wsrep provider
      if [ ${GALERA} = "yes" ]; then
        for gv in ${galera_versions}; do
          if [ "${ARCH}" = "amd64" ]; then
            if [ "${REPONAME}" = "centos5" ] || [ "${REPONAME}" = "rhel5" ]; then
              rsync -avP ~/galera-${gv}/*rhel5.x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora17" ] ; then
              rsync -avP ~/galera-${gv}/*fc17.x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora18" ] ; then
              rsync -avP ~/galera-${gv}/*fc18.x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora19" ] ; then
              rsync -avP ~/galera-${gv}/*fc19.x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora20" ] ; then
              rsync -avP ~/galera-${gv}/*fc20.x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            else
              rsync -avP ~/galera-${gv}/*rhel6.x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
            fi
          else
            if [ "${REPONAME}" = "centos5" ] || [ "${REPONAME}" = "rhel5" ]; then
              rsync -avP  ~/galera-${gv}/*rhel5.i386.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora17" ] ; then
              rsync -avP ~/galera-${gv}/*fc17.i686.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora18" ] ; then
              rsync -avP ~/galera-${gv}/*fc18.i686.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora19" ] ; then
              rsync -avP ~/galera-${gv}/*fc19.i386.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "fedora20" ] ; then
              rsync -avP ~/galera-${gv}/*fc20.i686.rpm ./${REPONAME}-${ARCH}/rpms/
            elif [ "${REPONAME}" = "centos7" ] || [ "${REPONAME}" = "rhel7" ]; then
              echo "+ no packages for ${REPONAME}-${ARCH}"
            else
              rsync -avP  ~/galera-${gv}/*rhel6.i*86.rpm ./${REPONAME}-${ARCH}/rpms/
            fi
          fi
        done
      fi
    #fi # End of dirty fix
  done
done

# Sign the packages
if [ "${ENTERPRISE}" = "yes" ]; then
  rpmsign --addsign --key-id=0xd324876ebe6a595f $(find . -name '*.rpm')
else
  rpmsign --addsign --key-id=0xcbcb082a1bb943db $(find . -name '*.rpm')
fi

# regenerate the md5sums.txt file (signing the packages changes their checksum)
for REPONAME in ${dists}; do
  for ARCH in amd64 x86; do
    if [ "${REPONAME}-${ARCH}" = "centos7-x86" ] || [ "${REPONAME}-${ARCH}" = "rhel7-x86" ]; then
      echo "+ no packages for ${REPONAME}-${ARCH}"
    else
      cd ${REPONAME}-${ARCH};
      pwd;
      rm -v md5sums.txt;
      md5sum $(find . -name '*.rpm') >> md5sums.txt;
      md5sum -c md5sums.txt;
      cd ../;
    fi
  done
done

# Here is where we actually create the YUM repositories for each distribution
# and sign the repomd.xml file
for REPONAME in ${dists}; do
  for ARCH in amd64 x86; do
    if [ "${REPONAME}-${ARCH}" = "centos7-x86" ] || [ "${REPONAME}-${ARCH}" = "rhel7-x86" ]; then
      echo "+ no packages for ${REPONAME}-${ARCH}"
    else
      echo ${REPONAME}-${ARCH}
      createrepo --database --pretty ${REPONAME}-${ARCH}
      if [ "${ENTERPRISE}" = "yes" ]; then
        gpg --detach-sign --armor -u 0xd324876ebe6a595f ${REPONAME}-${ARCH}/repodata/repomd.xml 
      else
        gpg --detach-sign --armor -u 0xcbcb082a1bb943db ${REPONAME}-${ARCH}/repodata/repomd.xml 
      fi
    fi
  done
done

# Add in a README for the srpms directory
for REPONAME in ${dists}; do
  for ARCH in amd64 x86; do
    if [ "${REPONAME}-${ARCH}" = "centos7-x86" ] || [ "${REPONAME}-${ARCH}" = "rhel7-x86" ]; then
      echo "+ no packages for ${REPONAME}-${ARCH}"
    else
      mkdir -vp ${REPONAME}-${ARCH}/srpms
      echo "Why do MariaDB RPMs not include the source RPM (SRPMS)?
https://mariadb.com/kb/en/why-do-mariadb-rpms-not-include-the-source-rpm-srpms
" >> ${REPONAME}-${ARCH}/srpms/README
    fi
  done
done

