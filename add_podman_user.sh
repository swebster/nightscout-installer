#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PODMAN_HOME='/home/podman'

function assign_subids() {
  mapfile -t -d: subuids < <(tail -1 /etc/subuid | cut -d: -f2,3)
  mapfile -t -d: subgids < <(tail -1 /etc/subgid | cut -d: -f2,3)

  local -r min_subuid=$((subuids[0] + subuids[1]))
  local -r min_subgid=$((subgids[0] + subgids[1]))

  local -r subuid_count=$(grep SUB_UID_COUNT /etc/login.defs | awk '{print $NF}')
  local -r subgid_count=$(grep SUB_GID_COUNT /etc/login.defs | awk '{print $NF}')

  local -r max_subuid=$((min_subuid + ${subuid_count:-65536} - 1))
  local -r max_subgid=$((min_subgid + ${subgid_count:-65536} - 1))

  sudo usermod \
    --add-subuids ${min_subuid}-${max_subuid} \
    --add-subgids ${min_subgid}-${max_subgid} \
    podman
}

if ! grep -q podman /etc/passwd; then
  sudo adduser --system --shell /bin/bash --home "${PODMAN_HOME}" podman
  # TODO: sudo chsh -s /usr/sbin/nologin podman
  sudo -u podman cp -t "${PODMAN_HOME}" /etc/skel/.*
fi

if [[ -d /run/systemd/system ]]; then
  if [[ ! -f /var/lib/systemd/linger/podman ]]; then
    sudo loginctl enable-linger podman
  fi
fi

if ! grep -q podman /etc/subuid; then
  assign_subids
fi

if ! sudo -u podman test -x "${PODMAN_HOME}/.local/bin/task"; then
  sudo install -o podman -g nogroup -t "${PODMAN_HOME}" "${SCRIPT_DIR}/install_task.sh"
  sudo -u podman "${PODMAN_HOME}/install_task.sh"
  sudo -u podman rm -f "${PODMAN_HOME}/install_task.sh"
fi
