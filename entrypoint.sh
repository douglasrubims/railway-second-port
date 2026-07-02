#!/bin/sh

set -euo pipefail

# for backwards compatibility, separates host and port from url
export TARGET_DOMAIN=${TARGET_DOMAIN:-${TARGET_HOST%:*}}
export TARGET_PORT=${TARGET_PORT:-${TARGET_HOST##*:}}

# strip http:// or https:// from domain if necessary
TARGET_DOMAIN=${TARGET_DOMAIN##*://}

echo using target: ${TARGET_DOMAIN} with port: ${TARGET_PORT}

exec caddy run --config Caddyfile --adapter caddyfile 2>&1
