#!/bin/bash - 
#===============================================================================
#
#          FILE:  mkrepo-yum.sh
# 
#         USAGE:  ./mkrepo-yum.sh <archive directory>
# 
#   DESCRIPTION:  A script to generate the yum repositories for our RPM packages
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
for REPONAME in centos5 centos6 rhel5 fedora16; do
  for ARCH in amd64 x86; do
    mkdir -v "${REPONAME}-${ARCH}"
    cp -avi ${ARCHDIR}/kvm-rpm-${REPONAME}-${ARCH}/* ./${REPONAME}-${ARCH}/
  done
done

# Sign the packages
rpm --addsign $(find . -name '*.rpm')

# regenerate the md5sums.txt file
for dir in $(ls -d *);do
  cd ${dir};
  pwd;
  rm -v md5sums.txt;
  md5sum $(find . -name '*.rpm') >> md5sums.txt;
  md5sum -c md5sums.txt;
  cd ../;
done

for dir in $(ls);do
  createrepo --database --pretty ${dir}
  gpg --detach-sign --armor -u 0xcbcb082a1bb943db ${dir}/repodata/repomd.xml 
done

