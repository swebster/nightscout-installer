# syntax=docker/dockerfile:1

ARG NIGHTSCOUT_VERSION

FROM nightscout/cgm-remote-monitor:${NIGHTSCOUT_VERSION}

USER root

RUN wget -O lib/server/env.js \
    https://raw.githubusercontent.com/swebster/cgm-remote-monitor/refs/heads/wip/api_secret_file/lib/server/env.js

USER node
