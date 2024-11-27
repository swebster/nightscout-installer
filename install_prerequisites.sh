#!/usr/bin/env bash

readonly packages=(podman podman-docker git systemd-container)

if [[ -x "$(command -v apt-get)" ]]; then
  sudo apt-get -y install "${packages[@]}"
elif [[ -x "$(command -v dnf)" ]]; then
  sudo dnf -y install "${packages[@]}"
else
  >&2 echo 'Error: unsupported package manager. Please install the following packages manually:'
  >&2 printf -- '- %s\n' "${packages[@]}"
  exit 1
fi
