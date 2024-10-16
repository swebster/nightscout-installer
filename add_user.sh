#!/usr/bin/env bash

function assign_subids() {
  mapfile -t -d: subuids < <(tail -1 /etc/subuid | cut -d: -f2,3)
  mapfile -t -d: subgids < <(tail -1 /etc/subgid | cut -d: -f2,3)

  local min_subuid=$((${subuids[0]}+${subuids[1]}))
  local min_subgid=$((${subgids[0]}+${subgids[1]}))

  local subuid_count=$(grep SUB_UID_COUNT /etc/login.defs | awk '{print $NF}')
  local subgid_count=$(grep SUB_GID_COUNT /etc/login.defs | awk '{print $NF}')

  local max_subuid=$((${min_subuid}+${subuid_count:-65536}-1))
  local max_subgid=$((${min_subgid}+${subgid_count:-65536}-1))

  sudo usermod \
    --add-subuids ${min_subuid}-${max_subuid} \
    --add-subgids ${min_subgid}-${max_subgid} \
    podman
}

if ! grep -q podman /etc/passwd; then
  sudo adduser --system --home /home/podman podman
fi

if [[ -d /run/systemd/system ]]; then
  if [[ ! -f /var/lib/systemd/linger/podman ]]; then
    sudo loginctl enable-linger podman
  fi
fi

if ! grep -q podman /etc/subuid; then
  assign_subids
fi
