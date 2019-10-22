#!/bin/bash

set -o nounset
set -o pipefail
set -o posix

err() {
  echo >&2 "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
  exit 1
}

# necessary commands
for cmd in wget mirmon; do
  command -v $cmd >/dev/null || err "$cmd command not found"
done

typeset -r var_mirror_list_url="https://github.com/$1/raw/$2/monitoring/mirmon/mariadb_mirror_list"

wget "$var_mirror_list_url" -O /usr/local/share/mariadb_mirror_list || err "Unable to get mirror list"
mirmon -q -get update >/opt/webhooks/mirmon_call.log
