#!/usr/bin/env bash

readonly PODMAN_HOME='/home/podman'
readonly PODMAN_BIN="${PODMAN_HOME}/.local/bin"
readonly PODMAN_SRC="${PODMAN_HOME}/src"
readonly COMPOSE_VERSION='v2.29.6'
readonly PODLET_VERSION='v0.3.0'
readonly TASK_VERSION='v3.39.2'
readonly YQ_VERSION='v4.44.3'

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
  # shellcheck disable=SC2016
  local -r docker_host='unix://${XDG_RUNTIME_DIR%/}/podman/podman.sock'

  # use a login shell so XDG_RUNTIME_DIR is defined when DOCKER_HOST is written to ~/.profile
  sudo -u podman --login sh -c "\
    curl -L ${compose_binary} -o ${PODMAN_BIN}/docker-compose && \
    chmod +x ${PODMAN_BIN}/docker-compose && \
    systemctl --user enable --now podman.socket && \
    printf 'export %s=%s\n' \
      COMPOSE_ENV_FILES .env,.env.local \
      DOCKER_HOST ${docker_host} >> ${PODMAN_HOME}/.profile"
}

function install_podlet() {
  local -r podlet_downloads='https://github.com/containers/podlet/releases/download'
  local -r podlet_dir='podlet-x86_64-unknown-linux-gnu'
  local -r podlet_archive="${podlet_downloads}/${PODLET_VERSION}/${podlet_dir}.tar.xz"

  sudo -u podman sh -c "\
    curl -L ${podlet_archive} | tar xJ -C ${PODMAN_HOME} && \
    mv -t ${PODMAN_BIN} ${PODMAN_HOME}/${podlet_dir}/podlet && \
    rm -rf ${PODMAN_HOME}/${podlet_dir}"
}

function install_yq() {
  local -r yq_downloads='https://github.com/mikefarah/yq/releases/download'

  sudo -u podman sh -c "\
    curl -L ${yq_downloads}/${YQ_VERSION}/yq_linux_amd64 -o ${PODMAN_BIN}/yq && \
    chmod +x ${PODMAN_BIN}/yq"
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

for dependency in {task,docker-compose,podlet,yq}; do
  if ! sudo -u podman test -x "${PODMAN_BIN}/${dependency}"; then
    "install_${dependency//-/_}"
  fi
done

if ! sudo -u podman test -d "${PODMAN_SRC}/nightscout"; then
  sudo -u podman sh -c "\
    mkdir -p ${PODMAN_SRC} && \
    git clone https://github.com/swebster/nightscout.git ${PODMAN_SRC}/nightscout"
fi
