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
	git config pull.ff only
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

declare -a annotations=(
	"--annotation" "org.opencontainers.image.authors=MariaDB Foundation"
	"--annotation" "org.opencontainers.image.documentation=https://hub.docker.com/_/mariadb"
	"--annotation" "org.opencontainers.image.source=https://github.com/MariaDB/mariadb-docker/tree/$(cd mariadb-docker/$master_branch; git rev-parse HEAD)/$master_branch"
	"--annotation" "org.opencontainers.image.licenses=GPL-2.0"
	"--annotation" "org.opencontainers.image.title=MariaDB Server $master_branch CI build" \
	"--annotation" "org.opencontainers.image.description=This is not a Release.\nBuild of the MariaDB Server from CI as of commit $commit" \
	"--annotation" "org.opencontainers.image.version=$mariadb_version+$commit" \
	"--annotation" "org.opencontainers.image.revision=$commit" )


annotate()
{
	for item in "${annotations[@]}"
	do
		echo " --annotation" \""$item"\"
	done
}

# Annotations - https://github.com/opencontainers/image-spec/blob/main/annotations.md#pre-defined-annotation-keys
build()
{
	arch=$1
	shift
	t=$(mktemp)
	buildah bud "$@" --build-arg REPOSITORY="[trusted=yes] https://ci.mariadb.org/$tarbuildnum/${arch}-${buildernamebase}/debs ./" \
	       --build-arg MARIADB_VERSION="1:$mariadb_version+maria~$base" \
		"${annotations[@]}" \
	       "mariadb-docker/$master_branch" | tee "${t}"
	image=$(tail -n 1 "$t")
	rm "$t"
}

#
# BUILD Image

if [ "${builderarch}" = aarch64 ]
then
	build aarch64 --arch arm64 --variant v8
else
	build "${builderarch}" --arch "${builderarch}"
fi

#
# TEST Image
#

if [ "${builderarch}" != amd64 ]
then
	export DOCKER_LIBRARY_START_TIMEOUT=35
else
	export DOCKER_LIBRARY_START_TIMEOUT=15
fi
mariadb-docker/.test/run.sh "$image"

#
# METADATA:

# Add manifest file of version and fix mariadb version in the configuration
# because otherwise 'buildah manifest add "$devmanifest" "$image"' would be sufficient

container=$(buildah from $image)
manifestfile=$(mktemp)
for item in "${annotations[@]}"
  do
    [ "$item" != "--annotation" ] && echo -e "$item\n"
  done > "$manifestfile"
buildah copy --add-history $container $manifestfile /manifest.txt
rm -f "$manifestfile"

# which file - see mariadb-docker commit 710e0cd9d9197becc954e9a4c572cb97dd1d07a8
if [[ $master_branch =~ 10.[234] ]]
then
	file=/etc/mysql/my.cnf
else
	file=/etc/mysql/mariadb.cnf
fi
# Set mariadb version according to a version that looks simlar to existing pattern, except with a commit id.
buildah run --add-history $container  sed -ie '/^\[mariadb/a version='"${mariadb_version}-MariaDB-${commit}" $file

#
# MAKE it part of the mariadb-devel manifest
#

buildmanifest()
{
	manifest=$1
	shift
	container=$1
	shift
	# create a manifest, and if it already exists, remove the one for the
	# current architecuture as we're replacing this.
	# This could happen due to triggered rebuilds on buildbot.

	buildah manifest create "$manifest" || buildah manifest inspect "$manifest" \
		| jq ".manifests[] | select( .platform.architecture == \"$builderarch\") | .digest" \
		| xargs --no-run-if-empty -n 1 buildah manifest remove "$manifest"

	t=$(mktemp)
	buildah commit "$@" --iidfile "$t" --manifest "$manifest" "$container"
	image=$(<$t)
	# $image is the wrong sha for annotation. Config vs Blogb?
	# Even below doesn't annotate manifest. Unknown reason, doesn't error
	buildah manifest inspect "$manifest" \
		| jq ".manifests[] | select( .platform.architecture == \"$builderarch\") | .digest" \
		| xargs --no-run-if-empty -n 1 buildah manifest annotate \
			"${annotations[@]}" \
			"$manifest"
	rm -f "$t"
}

devmanifest=mariadb-devel-$master_branch-$commit

buildmanifest $devmanifest $container

#
# MAKE Debug manifest

# linux-tools-common for perf
buildah run --add-history "$container" sh -c \
	"apt-get update \
	&& apt-get install -y linux-tools-common gdbserver \
	&& dpkg-query  --showformat='\${Package},\${Version},\${Architecture}\n' --show | grep mariadb \
	| while IFS=, read  pkg version arch; do \
          [ \$arch != all ] && apt-get install -y \${pkg}-dbgsym=\${version} ;
        done; \
	rm -rf /var/lib/apt/lists/*"

debugmanifest=mariadb-debug-$master_branch-$commit

buildmanifest $debugmanifest $container --rm

if [[ $master_branch =~ 10.[234] ]]
then
	expected=3
else
	expected=4
fi

#
#
# PUSHIT - if the manifest if complete, i.e. all supported arches are there, we push
#

manifestcleanup()
{
	manifest=$1
	t=$(mktemp)
	buildah manifest inspect "$manifest" | tee "${t}"
	# A manifest is an image type that podman can remove
	podman images --filter dangling=true --format '{{.ID}} {{.Digest}}' | \
		while read line
		do
			id=${line% *}
			digest=${line#* }
			echo id=$id digest=$digest
			if [ -n "$(jq ".manifests[].digest  |select(. == \"$digest\")" < "$t")" ]
			then
				podman rmi "$id"
			fi
		done
	rm "$t"
	podman rmi "$manifest"
}

if [[ $(buildah manifest inspect "$devmanifest" | jq '.manifests | length') -ge $expected ]]
then
	buildah manifest push --all --rm "$devmanifest" "docker://quay.io/mariadb-foundation/mariadb-devel:$master_branch"
	buildah manifest push --all --rm "$debugmanifest" "docker://quay.io/mariadb-foundation/mariadb-debug:$master_branch"

	#manifestcleanup "$devmanifest"
	#manifestcleanup "$debugmanifest"

	buildah images
	# lost and forgotten (or just didn't make enough manifest items - build failure on an arch)
	# Note *: coming to a buildah update sometime - epnoc timestamps - https://github.com/containers/buildah/pull/3482
	lastweek=$(date +%s --date='1 week ago')
	# old ubuntu and base images that got updated so are Dangling
	podman images --format=json | jq ".[] | select(.Created <= $lastweek and .Dangling) | .Id" | xargs --no-run-if-empty podman rmi
	# clean buildah containers
	buildah containers  --format "{{.ContainerID}}" | xargs --no-run-if-empty buildah  rm
	# clean images
	# (Note *) buildah images --json |  jq ".[] | select(.readonly ==false) |  select(.created <= $lastweek) | select( .names == null) | .id" | xargs --no-run-if-empty buildah rmi
	buildah images --json |  jq ".[] | select(.readonly ==false) |  select(.createdatraw | sub(\"(?<full>[^.]*).[0-9]+Z\"; \"\\(.full)Z\") | fromdateiso8601 <= $lastweek) | select( .names == null) | .id" | xargs --no-run-if-empty buildah rmi
	# clean manifests
	# (Note *) buildah images --json |  jq ".[] | select(.readonly ==false) |  select(.created <= $lastweek) | select( try .names[0]? catch \"\" | startswith(\"localhost/mariadb-\") ) | .id" | xargs --no-run-if-empty buildah manifest rm
	buildah images --json |  jq ".[] | select(.readonly ==false) |  select(.createdatraw | sub(\"(?<full>[^.]*).[0-9]+Z\"; \"\\(.full)Z\") | fromdateiso8601 <= $lastweek) | select( try .names[0]? catch \"\" | startswith(\"localhost/mariadb-\") ) | .id" | xargs --no-run-if-empty buildah manifest rm
	buildah images
fi

# not sure why these are leaking, however remove symlinks that don't link to anything
find /tmp/run-1000/libpod/tmp/socket -xtype l ! -exec test -e {} \; -ls -delete
