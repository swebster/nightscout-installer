# syntax=docker/dockerfile:1

ARG CADDY_VERSION

FROM caddy:${CADDY_VERSION}-builder AS builder

ARG CLOUDFLARE_VERSION

RUN xcaddy build \
  --with github.com/caddy-dns/cloudflare@${CLOUDFLARE_VERSION}

FROM caddy:${CADDY_VERSION}

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
