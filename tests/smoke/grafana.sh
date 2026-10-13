#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    printf 'Usage: %s HOST_OR_IP\n' "$0" >&2
    exit 2
fi

target="$1"
base_url="http://${target}:3000"

health="$(curl --fail --silent --show-error "${base_url}/api/health")"
printf '%s' "$health" | grep -q '"database": *"ok"'
printf 'Grafana is healthy on %s\n' "$base_url"
