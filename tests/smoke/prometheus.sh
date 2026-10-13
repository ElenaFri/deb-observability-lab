#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    printf 'Usage: %s HOST_OR_IP\n' "$0" >&2
    exit 2
fi

target="$1"
base_url="http://${target}:9090"

curl --fail --silent --show-error "${base_url}/-/healthy" >/dev/null
printf 'Prometheus is healthy on %s\n' "$base_url"

up_result="$(curl --fail --silent --show-error "${base_url}/api/v1/query?query=up")"
printf '%s' "$up_result" | grep -q '"status":"success"'
printf 'Prometheus answered the "up" query on %s\n' "$base_url"
