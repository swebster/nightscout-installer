#!/usr/bin/env bash

readonly PODMAN_HOME='/home/podman'
readonly PODMAN_BIN="${PODMAN_HOME}/.local/bin"
readonly COMPOSE_VERSION='v2.29.6'
readonly TASK_VERSION='v3.39.2'

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

function install_task() {
  local -r task_installer="${PODMAN_HOME}/install_task.sh"

  sudo -u podman sh -c "\
    curl -L https://taskfile.dev/install.sh -o ${task_installer} && \
    chmod +x ${task_installer} && \
    ${task_installer} -d -b ${PODMAN_BIN} ${TASK_VERSION} && \
    rm -f ${task_installer}"
}

function install_docker_compose() {
  local -r docker_downloads='https://github.com/docker/compose/releases/download'
  local -r compose_binary="${docker_downloads}/${COMPOSE_VERSION}/docker-compose-linux-x86_64"
  local -r docker_host='unix://${XDG_RUNTIME_DIR%/}/podman/podman.sock'

  sudo -u podman -i sh -c "\
    curl -L ${compose_binary} -o ${PODMAN_BIN}/docker-compose && \
    chmod +x ${PODMAN_BIN}/docker-compose && \
    systemctl --user enable --now podman.socket && \
    printf \"\nexport DOCKER_HOST=${docker_host}\n\" >> ${PODMAN_HOME}/.profile"
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

if ! sudo -u podman test -x "${PODMAN_BIN}/task"; then
  install_task
fi

if ! sudo -u podman test -x "${PODMAN_BIN}/docker-compose"; then
  install_docker_compose
fi
