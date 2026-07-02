#!/bin/sh

set -euo pipefail

if [ -f .env ]; then
	set -a
	# shellcheck disable=SC1091
	. ./.env
	set +a
fi

# for backwards compatibility, separates host and port from url
export TARGET_DOMAIN=${TARGET_DOMAIN:-${TARGET_HOST%:*}}
export TARGET_PORT=${TARGET_PORT:-${TARGET_HOST##*:}}

# strip http:// or https:// from domain if necessary
TARGET_DOMAIN=${TARGET_DOMAIN##*://}

if [ -z "${TARGET_DOMAIN:-}" ] || [ -z "${TARGET_PORT:-}" ]; then
	echo "TARGET_DOMAIN and TARGET_PORT must be set (via .env or environment)" >&2
	exit 1
fi

export TARGET_DOMAIN

echo using target: "${TARGET_DOMAIN}" with port: "${TARGET_PORT}"
echo proxy listening on port: 3000

exec caddy run --config Caddyfile --adapter caddyfile 2>&1
