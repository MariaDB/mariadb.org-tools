#!/bin/bash

set -xeuvo pipefail

# container builds copy permissions and
# depend on go+rx permissions
umask 0002
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
image=quay.io/mariadb-foundation/mariadb-devel:$master_branch

if [[ "$buildername" =~ 2004 ]]; then
	base=focal
else
	base=bionic
fi

buildah bud --build-arg REPOSITORY="[trusted=yes] https://ci.mariadb.org/$tarbuildnum/$buildername/debs ./" --build-arg MARIADB_VERSION="1:$mariadb_version+maria~$base" --tag "$image" "mariadb-docker/$master_branch"

mariadb-docker/.test/run.sh "$image"

podman push "$image"
