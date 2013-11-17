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

set -e

eval $(gpg-agent --daemon)

ARCHDIR="$1"

dists="centos5 rhel5 centos6 rhel6 fedora18 fedora19"
#dists="centos5 rhel5 centos6 fedora17 fedora18"
#dists="centos5 centos6 fedora17 fedora18"

if [ ! -d "$ARCHDIR" ] ; then
    echo 1>&2 "Usage: $0 <archive directory>"
    exit 1
fi


# Copy over the packages
#for REPONAME in centos5 rhel5; do
for REPONAME in ${dists}; do
  for ARCH in amd64 x86; do
    mkdir -vp "${REPONAME}-${ARCH}"
    #cp -avi ${ARCHDIR}/kvm-rpm-${REPONAME}-${ARCH}/* ./${REPONAME}-${ARCH}/


    if [ "${REPONAME}" = "rhel6" ]; then
      rsync -avP ${ARCHDIR}/kvm-rpm-centos6-${ARCH}/ ./${REPONAME}-${ARCH}/
    ## tmp fix for broken rhel5-x86 builds
    #elif [ "${REPONAME}" = "rhel5" ]; then
    #  if [ "${ARCH}" = "x86" ]; then
    #    cp -avi ${ARCHDIR}/kvm-rpm-centos5-${ARCH}/* ./${REPONAME}-${ARCH}/
    #  else
    #    cp -avi ${ARCHDIR}/kvm-rpm-${REPONAME}-${ARCH}/* ./${REPONAME}-${ARCH}/
    #  fi
    ## end of tmp fix for broken rhel5-x86 builds
    else
      rsync -avP ${ARCHDIR}/kvm-rpm-${REPONAME}-${ARCH}/ ./${REPONAME}-${ARCH}/
    fi


    # Copy in the Galera wsrep provider
    if [ "${ARCH}" = "amd64" ]; then
      if [ "${REPONAME}" = "centos5" ] || [ "${REPONAME}" = "rhel5" ]; then
        rsync -avP ~/galera/*rhel5.x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
      elif [ "${REPONAME}" = "fedora17" ] ; then
        rsync -avP ~/galera/*fc17.x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
      elif [ "${REPONAME}" = "fedora18" ] ; then
        rsync -avP ~/galera/*fc18.x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
      elif [ "${REPONAME}" = "fedora19" ] ; then
        rsync -avP ~/galera/*fc19.x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
      else
        rsync -avP ~/galera/*rhel6.x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
      fi
    else
      if [ "${REPONAME}" = "centos5" ] || [ "${REPONAME}" = "rhel5" ]; then
        rsync -avP  ~/galera/*rhel5.i386.rpm ./${REPONAME}-${ARCH}/rpms/
      elif [ "${REPONAME}" = "fedora17" ] ; then
        rsync -avP ~/galera/*fc17.i686.rpm ./${REPONAME}-${ARCH}/rpms/
      elif [ "${REPONAME}" = "fedora18" ] ; then
        rsync -avP ~/galera/*fc18.i686.rpm ./${REPONAME}-${ARCH}/rpms/
      elif [ "${REPONAME}" = "fedora19" ] ; then
        rsync -avP ~/galera/*fc19.i386.rpm ./${REPONAME}-${ARCH}/rpms/
      else
        rsync -avP  ~/galera/*rhel6.i386.rpm ./${REPONAME}-${ARCH}/rpms/
      fi
    fi
  done
done

# Sign the packages
rpm --addsign $(find . -name '*.rpm')

# regenerate the md5sums.txt file (signing the packages changes their checksum)
for REPONAME in ${dists}; do
  for ARCH in amd64 x86; do
    cd ${REPONAME}-${ARCH};
    pwd;
    rm -v md5sums.txt;
    md5sum $(find . -name '*.rpm') >> md5sums.txt;
    md5sum -c md5sums.txt;
    cd ../;
  done
done

# Here is where we actually create the YUM repositories for each distribution
# and sign the repomd.xml file
for REPONAME in ${dists}; do
  for ARCH in amd64 x86; do
    echo ${REPONAME}-${ARCH}
    createrepo --database --pretty ${REPONAME}-${ARCH}
    gpg --detach-sign --armor -u 0xcbcb082a1bb943db ${REPONAME}-${ARCH}/repodata/repomd.xml 
  done
done

# Add in a README for the srpms directory
for REPONAME in ${dists}; do
  for ARCH in amd64 x86; do
    mkdir -vp ${REPONAME}-${ARCH}/srpms
    echo "Why do MariaDB RPMs not include the source RPM (SRPMS)?
http://kb.askmonty.org/en/why-do-mariadb-rpms-not-include-the-source-rpm-srpms
" >> ${REPONAME}-${ARCH}/srpms/README
  done
done

