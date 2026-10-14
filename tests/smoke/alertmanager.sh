#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
    printf 'Usage: %s HOST_OR_IP\n' "$0" >&2
    exit 2
fi

target="$1"
am_url="http://${target}:9093"
prom_url="http://${target}:9090"

curl --fail --silent --show-error "${am_url}/-/healthy" >/dev/null
printf 'Alertmanager is healthy on %s\n' "$am_url"

alertmanagers="$(curl --fail --silent --show-error "${prom_url}/api/v1/alertmanagers")"
printf '%s' "$alertmanagers" | grep -q '9093'
printf 'Prometheus has registered the Alertmanager on %s\n' "$prom_url"
