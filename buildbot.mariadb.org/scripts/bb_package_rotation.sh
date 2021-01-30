#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o posix

err() {
  echo >&2 "[$(date +'%Y-%m-%dT%H:%M:%S%z')] ERROR: $*"
  exit 1
}

echo_date() {
  echo -e "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

typeset -r VAR_SCRIPT_LOCK="/home/buildmaster/bb_packages_rotation.lock"
typeset -r VAR_NFS_DIR="/mnt/autofs/nfs/buildbot/packages"
typeset -r VAR_LOCAL_DIR="/srv/buildbot/packages"

[[ ! -f $VAR_SCRIPT_LOCK ]] || {
  echo_date "bb packages rotation already running"
  exit 1
}

trap 'rm -f $VAR_SCRIPT_LOCK' EXIT
touch $VAR_SCRIPT_LOCK

[[ -d $VAR_NFS_DIR ]] || err "$VAR_NFS_DIR not found"
[[ -d $VAR_LOCAL_DIR ]] || err "$VAR_LOCAL_DIR not found"

IGNORE_DIR="helper_files"

typeset -r VAR_NFS_USAGE=$(df $VAR_NFS_DIR | tail -1 | awk '{print $5}')
if ((${VAR_NFS_USAGE/\%/} >= 70)); then
  echo_date "cleaning 10 oldest build"
  cd $VAR_NFS_DIR || err "cd $VAR_NFS_DIR"
  # shellcheck disable=SC2012
  ls -rt -I $IGNORE_DIR | head -10 | xargs rm -rv || err "cleaning 10 oldest build"
fi

typeset -r VAR_LOCAL_USAGE=$(df $VAR_LOCAL_DIR | tail -1 | awk '{print $5}')
if ((${VAR_LOCAL_USAGE/\%/} >= 77)); then
  echo_date "moving 10 oldest build"
  cd $VAR_LOCAL_DIR || err "cd $VAR_LOCAL_DIR"
  [[ -L older_builds ]] || err "older_builds not found"
  # shellcheck disable=SC2012
  for dir in $(ls -rt -I $IGNORE_DIR | grep -v older_builds | head -10); do
    mv -v "$dir" older_builds/ || err "moving $dir to older_builds/"
  done
fi
