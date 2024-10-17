#!/usr/bin/env bash

TARGET_DIR="$HOME/.local/bin"
TASK_VERSION='v3.39.2'

if [[ ! -f "$TARGET_DIR/task" ]]; then
  sh -c "$(curl -L https://taskfile.dev/install.sh)" -- -d -b "$TARGET_DIR" "$TASK_VERSION"
fi
