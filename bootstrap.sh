#!/usr/bin/env bash

readonly PODMAN_HOME='/home/podman'
readonly PODMAN_BIN="${PODMAN_HOME}/.local/bin"
readonly PODMAN_SRC="${PODMAN_HOME}/src"
readonly COMPOSE_VERSION='v2.39.4'
readonly PODLET_VERSION='v0.3.0'
readonly TASK_VERSION='v3.45.4'
readonly JQ_VERSION='jq-1.8.1'
readonly YQ_VERSION='v4.47.2'

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

function install_prerequisites() {
  local packages=(podman podman-docker git systemd-container)

  if [[ -x "$(command -v apt-get)" ]]; then
    sudo apt-get -y install "${packages[@]}"
  elif [[ -x "$(command -v dnf)" ]]; then
    packages+=(xz)
    sudo dnf -y install "${packages[@]}"
  else
    >&2 echo 'Error: unsupported package manager. Please install the following packages manually:'
    >&2 printf -- '- %s\n' "${packages[@]}"
    exit 1
  fi
}

function install_task() {
  local -r task_installer="${PODMAN_HOME}/install_task.sh"
  local -r podman_completions="${PODMAN_HOME}/.local/share/bash-completion/completions"

  sudo -u podman sh -c "\
    curl -L https://taskfile.dev/install.sh -o ${task_installer} && \
    chmod +x ${task_installer} && \
    ${task_installer} -d -b ${PODMAN_BIN} ${TASK_VERSION} && \
    rm -f ${task_installer} && \
    mkdir -p ${podman_completions} && \
    ${PODMAN_BIN}/task --completion bash > ${podman_completions}/task"
}

function install_docker_compose() {
  local -r docker_downloads='https://github.com/docker/compose/releases/download'
  local -r compose_binary="${docker_downloads}/${COMPOSE_VERSION}/docker-compose-linux-x86_64"
  local -r config_dir="${PODMAN_HOME}/.config/containers"
  local -r disable_compose_warnings='[engine]\\ncompose_warning_logs=false\\n'

  sudo -u podman sh -c "\
    curl -L ${compose_binary} -o ${PODMAN_BIN}/docker-compose && \
    chmod +x ${PODMAN_BIN}/docker-compose && \
    mkdir -p ${config_dir} && \
    printf ${disable_compose_warnings} > ${config_dir}/containers.conf"
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

function install_jq() {
  local -r jq_downloads='https://github.com/jqlang/jq/releases/download'

  sudo -u podman sh -c "\
    curl -L ${jq_downloads}/${JQ_VERSION}/jq-linux-amd64 -o ${PODMAN_BIN}/jq && \
    chmod +x ${PODMAN_BIN}/jq"
}

function install_yq() {
  local -r yq_downloads='https://github.com/mikefarah/yq/releases/download'

  sudo -u podman sh -c "\
    curl -L ${yq_downloads}/${YQ_VERSION}/yq_linux_amd64 -o ${PODMAN_BIN}/yq && \
    chmod +x ${PODMAN_BIN}/yq"
}

install_prerequisites

if ! grep -q podman /etc/passwd; then
  sudo useradd --system --shell /bin/bash --create-home --home-dir "${PODMAN_HOME}" podman
  sudo -u podman touch "${PODMAN_HOME}/.hushlogin"
fi

if [[ -d /run/systemd/system ]]; then
  sudo systemctl -M podman@ --user enable --now podman.socket podman-auto-update.timer
  if [[ ! -f /var/lib/systemd/linger/podman ]]; then
    sudo loginctl enable-linger podman
  fi
fi

if ! grep -q podman /etc/subuid; then
  assign_subids
fi

for dependency in {task,docker-compose,podlet,jq,yq}; do
  if ! sudo -u podman test -x "${PODMAN_BIN}/${dependency}"; then
    "install_${dependency//-/_}"
  fi
done

if ! sudo -u podman test -d "${PODMAN_SRC}/nightscout-installer"; then
  sudo -u podman sh -c "\
    mkdir -p ${PODMAN_SRC} && git clone \
      https://github.com/swebster/nightscout-installer.git ${PODMAN_SRC}/nightscout-installer"
fi

echo 'User "podman" has been created to run services in containers.'
echo 'Execute "sudo machinectl shell podman@.host" to start a shell as that user.'
