#!/usr/bin/env bash

# Short HOWTO
#
# 1 - put this script into directory with prepared rpms or
# specify it manually using --repository <PATH_TO_REPO>
#
# 2 - 'prepared rpms' means that dir must be already indexed with `createrepo`
# and rpms must be already signed to do not change md5/sha256 sums later
#
# 3 - run this script to generate updateinfo xml file
# ./gen-updateinfo.sh --repository /srv/repo/rhel/7/rpms/ --platform-name RedHat --platform-version 7
#
# 4 - run `modifyrepo /tmp/updateinfo.xml <PATH_TO_REPO>/repodata
#
# NB - this script is looking for reference package (MariaDB-server)
# to set some general variables before rpm files will be processed.
# to use another package as reference you will need `--refpackage <PATH_TO_RPM>`
#
# Also, you must have RPM binary installed, even deb version to query packages

set -e

PLATFORM_NAME=""
PLATFORM_VER=""

UPDATEINFO='/tmp/updateinfo.xml'
REPOPATH=$(dirname $0)
# SEVERITY may be critical, important, moderate, bugfix, enhancement
# script doesn't check for correct value, please be careful!
# should be capitalized for RHEL
SEVERITY=Moderate
#
# may be recommended, security, optional, feature, enhancement, newpackage, bugfix, etc
UPDATETYPE=security
#
if [[ ${LANG} != 'en_US.UTF-8' ]]; then
  echo "Locale should be UTF for XML generation, please set en_US.UTF-8"
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case $1 in
    --platform-name)
      PLATFORM_NAME=$2
      shift 2
      ;;
    --platform-version)
      PLATFORM_VER=$2
      shift 2
      ;;
    --repository)
      REPOPATH=$2
      shift 2
      ;;
    --refpackage)
      REFPACKAGE=$2
      shift 2
      ;;
    --severity)
      SEVERITY=$2
      shift 2
      ;;
    --update-type)
      UPDATETYPE=$2
      shift 2
      ;;
    *)
      ;;
  esac
done
#
#
if [[ -z "${PLATFORM_NAME}" ]]; then
  echo "Platform name is empty! Use --platform-name to ${0}"
  exit 1
fi
if [[ -z "${PLATFORM_VER}" ]]; then
  echo "Platform version is empty! Use --platform-version to ${0}"
  exit 1
fi
#
# ref package is needed to get required metadata before any file
# is processed in directory. Cannot be empty
[[ -z "${REFPACKAGE}" ]] && REFPACKAGE="$(find ${REPOPATH} -type f -name 'MariaDB-server*.rpm' ! -name '*debuginfo*' | tail -n 1)"
[[ -n "${REFPACKAGE}" ]] && echo "=> Reference package is set to ${REFPACKAGE}..."

RPMS=$(find ${REPOPATH} -type f -name '*.rpm')
[[ -z "${RPMS}" ]] && echo "No RPM files found!" && exit 1

# getting metadata from ref package
VERSION=$(rpm -qp --qf "%{version}" ${REFPACKAGE})
SHORTVER=${VERSION%_*}
RNVER=${SHORTVER//[\._]/}
RNURL=https://mariadb.com/kb/en/mariadb-${RNVER}-release-notes/
REFVENDOR=$(rpm -qp --qf "%{vendor}" ${REFPACKAGE})
EMAIL="MariaDB Developers <maria-developers@mariadb.org>"
PRODUCT="MariaDB"

if [[ "${REFVENDOR}" =~ "MariaDB Corporation" ]]; then
  PRODUCT="MariaDB-Enterprise"
  EMAIL="MariaDB Corporation <pkg-maintainer@mariadb.com>"
  RNVER=${VERSION//[\._]/-}
  RNURL="https://mariadb.com/docs/release-notes/mariadb-enterprise-server-${RNVER}/"
fi

echo '<?xml version="1.0" encoding="UTF-8"?>' > ${UPDATEINFO}
echo '<updates>' >> ${UPDATEINFO}
echo "  <update from=\"${EMAIL}\" status=\"stable\" type=\"${UPDATETYPE}\" version=\"2.0\">" >> ${UPDATEINFO}
echo "    <id>${PRODUCT}-${VERSION}</id>" >> ${UPDATEINFO}
echo "    <title>${PRODUCT} $(date +%B/%Y) update to ${VERSION}</title>" >> ${UPDATEINFO}
echo "    <severity>${SEVERITY}</severity>" >> ${UPDATEINFO}
echo "    <issued date=\"$(date -u '+%F %T %Z')\"></issued>" >> ${UPDATEINFO}
echo "    <rights>Copyright (C) $(date +%Y) ${REFVENDOR}.</rights>" >> ${UPDATEINFO}
echo "    <release>${PRODUCT} ${VERSION} release</release>" >> ${UPDATEINFO}
echo "    <references>" >> ${UPDATEINFO}
echo "      <reference href=\"https://mariadb.com/kb/en/library/security/\" id=\"\" title=\"List of CVEs fixed in ${PRODUCT}\" type=\"other\"/>" >> ${UPDATEINFO}
echo "      <reference href=\"${RNURL}\" id=\"${RNVER//-/}-rn\" title=\"Issues fixed in ${PRODUCT} ${SHORTVER}\" type=\"self\"/>" >> ${UPDATEINFO}
echo "    </references>" >> ${UPDATEINFO}
echo "    <pkglist>" >> ${UPDATEINFO}
echo "      <collection short=\"${PRODUCT}-${VERSION}\">" >> ${UPDATEINFO}
echo "        <name>${PRODUCT} release ${VERSION} for ${PLATFORM_NAME} ${PLATFORM_VER}</name>" >> ${UPDATEINFO}

for _package in ${RPMS}; do
  FILENAME=$(basename ${_package})
  echo " * Processing ${FILENAME}..."
  NAME=$(rpm -qp --qf "%{name}" ${_package})
  VENDOR=$(rpm -qp --qf "%{vendor}" ${_package})
  VERSION=$(rpm -qp --qf "%{version}" ${_package})
  RELEASE=$(rpm -qp --qf "%{release}" ${_package})
  EPOCH=$(rpm -qp --qf "%{epochnum}" ${_package})
  ARCH=$(rpm -qp --qf "%{arch}" ${_package})
  if [[ "${VENDOR}" =~ "${REFVENDOR}" ]] && [[ "${NAME}" =~ MariaDB ]]; then
    SRC="MariaDB-${VERSION}-${RELEASE}.src.rpm"
  else
    SRC=$(rpm -qp --qf "%{sourcerpm}" ${_package})
  fi
  SHA256=$(sha256sum ${_package} | awk '{print $1}')
  echo "        <package name=\"${NAME}\" version=\"${VERSION}\" release=\"${RELEASE}\" epoch=\"${EPOCH}\" arch=\"${ARCH}\" src=\"${SRC}\">" >> ${UPDATEINFO}
  echo "          <filename>${FILENAME}</filename>" >> ${UPDATEINFO}
  echo "          <sum type=\"sha256\">${SHA256}</sum>" >> ${UPDATEINFO}
  echo "        </package>" >> ${UPDATEINFO}
done

echo "      </collection>" >> ${UPDATEINFO}
echo "    </pkglist>" >> ${UPDATEINFO}
echo '  </update>' >> ${UPDATEINFO}
echo '</updates>' >> ${UPDATEINFO}
#
echo "=> Updateinfo file generated as ${UPDATEINFO}"

