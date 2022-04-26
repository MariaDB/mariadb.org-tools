#!/usr/bin/env bash
# shellcheck disable=SC2154

# Include with:
# . ./bash_lib.sh

bb_log_info() {
  echo >&1 "INFO: $*"
}

bb_log_warn() {
  echo >&1 "WARNING: $*"
}

bb_log_err() {
  echo >&2 "ERROR: $*"
}

err() {
  echo >&2 "ERROR: $*"
  exit 1
}

manual_run_switch() {
  # check if we are in Buildbot CI or not
  # //TEMP find a better generic way here (we might want to be able to run it
  # manually and as the buildbot user)
  if [[ $(whoami) != "buildbot" ]]; then
    if [[ -z $1 ]]; then
      echo "Please provide the build URL, example:"
      echo "$0 https://buildbot.mariadb.org/#/builders/171/builds/7351"
      exit 1
    else
      # define environment variables from build properties
      for cmd in jq wget; do
        command -v $cmd >/dev/null ||
          err "$cmd command not found"
      done
      # get buildid
      buildid=$(wget -qO- "${1/\#/api/v2}" | jq -r '.builds[] | .buildid')
      # get build properties
      wget -q "https://buildbot.mariadb.org/api/v2/builds/$buildid/properties" -O properties.json ||
        err "unable to get build properties from $1"
      # //TEMP do better with jq filtering
      for var in $(jq -r '.properties[]' properties.json | grep -v warnings-count | grep ": \[" | cut -d \" -f2); do
        export "$var"="$(jq -r ".properties[] | .${var}[0]" properties.json)"
      done
    fi
  fi

  # for RPM we have to download artifacts from ci.mariadb.org
  if command -v rpm >/dev/null; then
    mkdir rpms
    wget -r -np -nH --cut-dirs=3 -A "*.rpm" "https://ci.mariadb.org/$tarbuildnum/$parentbuildername/rpms" -P rpms
  fi
}

apt_get_update() {
  res=1
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if sudo apt-get update; then
      res=0
      break
    fi
    bb_log_warn "apt-get update failed, retrying ($i)"
    sleep 5
  done

  if ((res != 0)); then
    bb_log_err "apt-get update failed"
    exit $res
  fi
}

wait_for_mysql_upgrade() {
  res=1
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    if pgrep -i 'mysql_upgrade|mysqlcheck|mysqlrepair|mysqlanalyze|mysqloptimize|mariadb-upgrade|mariadb-check'; then
      bb_log_info "wait for mysql_upgrade to finish ($i)"
      sleep 2
    else
      res=0
      break
    fi
  done
  if ((res != 0)); then
    bb_log_err "mysql_upgrade or alike have not finished in reasonable time"
  fi
}
