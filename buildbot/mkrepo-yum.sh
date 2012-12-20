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

if [ ! -d "$ARCHDIR" ] ; then
    echo 1>&2 "Usage: $0 <archive directory>"
    exit 1
fi


# Copy over the packages
#for REPONAME in centos5 rhel5; do
for REPONAME in centos5 centos6 rhel5 fedora16 fedora17; do
  for ARCH in amd64 x86; do
    mkdir -vp "${REPONAME}-${ARCH}"
    cp -avi ${ARCHDIR}/kvm-rpm-${REPONAME}-${ARCH}/* ./${REPONAME}-${ARCH}/
    # Copy in the Galera wsrep provider
    if [ "${ARCH}" = "amd64" ]; then
      cp -avi ~/galera/*.x86_64.rpm ./${REPONAME}-${ARCH}/rpms/
    else
      cp -avi  ~/galera/*.i386.rpm ./${REPONAME}-${ARCH}/rpms/
    fi
  done
done

# Sign the packages
rpm --addsign $(find . -name '*.rpm')

# regenerate the md5sums.txt file (signing the packages changes their checksum)
for dir in $(ls -d *);do
  cd ${dir};
  pwd;
  rm -v md5sums.txt;
  md5sum $(find . -name '*.rpm') >> md5sums.txt;
  md5sum -c md5sums.txt;
  cd ../;
done

# Here is where we actually create the YUM repositories for each distribution
# and sign the repomd.xml file
for dir in $(ls);do
  createrepo --database --pretty ${dir}
  gpg --detach-sign --armor -u 0xcbcb082a1bb943db ${dir}/repodata/repomd.xml 
done

# Add in a README for the srpms directory
for dir in $(ls);do
  mkdir -vp ${dir}/srpms
  echo "Why do MariaDB RPMs not include the source RPM (SRPMS)?
http://kb.askmonty.org/en/why-do-mariadb-rpms-not-include-the-source-rpm-srpms
" >> ${dir}/srpms/README
done

