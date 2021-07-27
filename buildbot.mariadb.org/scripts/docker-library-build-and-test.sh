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

buildernamebase=${buildername#*-}

build()
{
	arch=$1
	shift
	buildah bud "$@" --build-arg REPOSITORY="[trusted=yes] https://ci.mariadb.org/$tarbuildnum/${arch}-${buildernamebase}/debs ./" --build-arg MARIADB_VERSION="1:$mariadb_version+maria~$base" --tag "$image-$arch" "mariadb-docker/$master_branch"
}


build amd64

mariadb-docker/.test/run.sh "$image-amd64"


manifest=mariadb-devel-$master_branch

buildah manifest create "$manifest" || buildah manifest inspect "$manifest" | jq '.manifests[].digest' | xargs -n 1 -r  buildah manifest  remove "$manifest"

buildah manifest add "$manifest" "$image-amd64"

# build multiarch
build aarch64 --arch arm64 --variant v8

buildah manifest add "$manifest" "$image-aarch64"

build ppc64le --arch ppc64le

buildah manifest add "$manifest" "$image-ppc64le"

#if [[ ! "$masterbranch" =~ 10.[234]  ]]
#then
#	build s390x --arch s390x
#	buildah manifest add "$manifest" "$image-s390x"
#fi
#
podman manifest push "$manifest" "docker://$image"
