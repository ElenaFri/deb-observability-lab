#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
    printf 'Usage: %s HOST_OR_IP\n' "$0" >&2
    exit 2
fi

target="$1"
metrics_url="http://${target}:9100/metrics"

curl --fail --silent --show-error "$metrics_url" \
    | grep --max-count=1 '^node_uname_info'

printf 'Node Exporter metrics are available on %s\n' "$metrics_url"
