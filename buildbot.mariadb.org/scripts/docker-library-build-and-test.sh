#!/bin/bash

set -xeuvo pipefail

if [ -d mariadb-docker ]; then
	pushd mariadb-docker
	git pull
	popd
else
	git clone https://github.com/MariaDB/mariadb-docker.git
fi

tarbuildnum=${1}
mariadb_version=${2}
mariadb_version=${mariadb_version#*-}
buildername=${3:-amd64-ubuntu-2004-deb-autobake}
master_branch=${4:-${mariadb_version%\.*}}
image=mdb-test:$master_branch

# Temp workaround to correct for arg being buildername instead of parentbuildername
if [ "$buildername" = amd64-rhel8-dockerlibrary ]; then
	if [ $master_branch = 10.2 ]; then
		buildername=amd64-ubuntu-1804-deb-autobake
	else
		buildername=amd64-ubuntu-2004-deb-autobake
	fi
fi

if [[ "$buildername" =~ 2004 ]]; then
	base=focal
else
	base=bionic
fi

buildah bud --build-arg REPOSITORY="[trusted=yes] https://ci.mariadb.org/$tarbuildnum/$buildername/debs ./" --build-arg MARIADB_VERSION="1:$mariadb_version+maria~$base" --tag "$image" "mariadb-docker/$master_branch"

mariadb-docker/.test/run.sh "$image"

