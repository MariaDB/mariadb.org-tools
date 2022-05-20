#!/usr/bin/env bash

# When the libvirt master starts, it creates an ssh connection to the worker
# machine for each defined worker. If for any reason that ssh connection drops
# (for example on a restart of the libvirtd daemon), then there will be build
# failures because workers are no more available. The master doesn't handle at
# all this and a master restart is needed.
# See: https://jira.mariadb.org/browse/MDBF-415

# This needs to be called as ExecStartPost= in the systemd unit file.
# See: /etc/systemd/system/buildbot-master-libvirt.service

watchdog() {
  VAR_BB_LIBVIRT_DIR="/srv/buildbot/master/master-libvirt"
  VAR_BB_LIBVIRT_CONF="$VAR_BB_LIBVIRT_DIR/master.cfg"

  while true; do
    FAIL=0
    VAR_QEMU_SSH_CONF=7
    # shellcheck disable=SC2009
    VAR_QEMU_SSH_CONNEXION=$(ps faux | grep -c "qemu:///")

    if ((VAR_QEMU_SSH_CONF != $((VAR_QEMU_SSH_CONNEXION - 1)))); then
      FAIL=1
    fi

    if ((FAIL == 0)); then
      /bin/systemd-notify WATCHDOG=1;
      sleep $((WATCHDOG_USEC / 2000000))
    else
      sleep 1
    fi
  done
}

watchdog &
