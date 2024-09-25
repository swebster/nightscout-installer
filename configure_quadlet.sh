#!/usr/bin/env bash

# generate intermediate compose file with interpolated variables
trap 'rm -f docker-compose.config.yml' EXIT
docker compose -f docker-compose.yml config --no-normalize -o docker-compose.config.yml

# revert .services.[].ports and volumes to short syntax for compatibility with podlet
# https://github.com/mikefarah/yq/#install
yq -Pi '.services *= (load("docker-compose.yml") |
    # just select the ports and volumes from the original file
    .services | .[] |= pick(["ports", "volumes"])
  )' docker-compose.config.yml

# generate quadlet configuration from the intermediate compose file
# https://github.com/containers/podlet?tab=readme-ov-file#install
podlet compose --pod docker-compose.config.yml
