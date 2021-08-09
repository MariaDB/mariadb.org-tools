#!/bin/bash

set -xeuvo pipefail

# container builds copy permissions and
# depend on go+rx permissions
umask 0002
if [ -d mariadb-docker ]; then
	pushd mariadb-docker
	git pull --ff-only
	popd
else
	git clone https://github.com/MariaDB/mariadb-docker.git
fi

tarbuildnum=${1}
mariadb_version=${2}
mariadb_version=${mariadb_version#*-}
buildername=${3:-amd64-ubuntu-2004-deb-autobake}
master_branch=${mariadb_version%\.*}
commit=${4:-0}

if [[ "$buildername" =~ 2004 ]]; then
	base=focal
else
	base=bionic
fi

buildernamebase=${buildername#*-}
builderarch=${buildername%%-*}

# Annotations - https://github.com/opencontainers/image-spec/blob/main/annotations.md#pre-defined-annotation-keys
build()
{
	arch=$1
	shift
	t=$(mktemp)
	buildah bud "$@" --build-arg REPOSITORY="[trusted=yes] https://ci.mariadb.org/$tarbuildnum/${arch}-${buildernamebase}/debs ./" \
	       --build-arg MARIADB_VERSION="1:$mariadb_version+maria~$base" \
	       --annotation org.opencontainers.image.authors="MariaDB Foundation" \
	       --annotation org.opencontainers.image.documentation=https://hub.docker.com/_/mariadb \
	       --annotation org.opencontainers.image.source=https://github.com/MariaDB/mariadb-docker/tree/$(cd mariadb-docker/$master_branch; git rev-parse HEAD)/$master_branch \
	       --annotation org.opencontainers.image.licenses=GPL-2.0 \
	       --annotation org.opencontainers.image.title="MariaDB Server $master_branch CI build" \
	       --annotation org.opencontainers.image.description="This is not a Release.\nBuild of the MariaDB Server from CI as of commit $commit" \
	       --annotation org.opencontainers.image.version=$mariadb_version+$commit \
	       --annotation org.opencontainers.image.revision=$commit \
	       "mariadb-docker/$master_branch" | tee "${t}"
	image=$(tail -n 1 "$t")
	rm "$t"
}

if [ "${builderarch}" = aarch64 ]
then
	build aarch64 --arch arm64 --variant v8
else
	build "${builderarch}" --arch "${builderarch}"
fi

if [ "${builderarch}" = amd64 ]
	mariadb-docker/.test/run.sh "$image"
fi

manifest=mariadb-devel-$master_branch-$commit

buildah manifest create "$manifest" || buildah manifest inspect "$manifest"

buildah manifest add "$manifest" "$image"

if [[ $master_branch =~ 10.[234] ]]
then
	expected=4
else
	expected=3
fi

if [[ $(buildah manifest inspect "$manifest" | jq '.manifests | length') -ge $expected ]]
then
	podman manifest push "$manifest" "docker://quay.io/mariadb-foundation/mariadb-devel:$master_branch"

	# A manifest is an image type that podman can remove
	podman rmi "$manifest"
	podman images --filter dangling=true --format '{{.ID}}' | xargs podman rmi
	podman images
fi

# not sure why these are leaking, however remove symlinks that don't link to anything
find /tmp/run-1000/libpod/tmp/socket -xtype l ! -exec test -e {} \; -delete
