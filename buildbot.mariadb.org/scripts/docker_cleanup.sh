#!/bin/bash

set -xeuvo pipefail

mariadb_version=${1}
mariadb_version=${mariadb_version#*-}
master_branch=${mariadb_version%\.*}

commit=${2:-}
branch=${3:-${master_branch}}

if [[ $branch =~ ^preview ]]; then
  container_tag=${branch#preview-[0-9]*\.[0-9]*-}
else
  container_tag=$master_branch
fi
# Container tags must be lower case.
container_tag=${container_tag,,*}

t=$(mktemp)
for m in mariadb-devel-${container_tag}-$commit mariadb-debug-${container_tag}-$commit
do
  echo cleanup $m
  buildah manifest inspect "$m" | jq '.manifests[]?.digest?' | tee -a "$t"
done

podman images --filter dangling=true --format '{{.ID}} {{.Digest}}' |
while read line; do
  id="${line% *}"
  digest="${line#* }"
  echo "id=$id digest=$digest"
  if grep "$digest" "$t"
  then
    echo -e "\nRemove image:"
    podman rmi "$id"
    echo
  fi
done

rm "$t"
for m in mariadb-devel-${container_tag}-$commit mariadb-debug-${container_tag}-$commit
do
  echo cleanup $m
  buildah manifest rm "$m"
done
