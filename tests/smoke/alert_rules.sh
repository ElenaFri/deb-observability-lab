#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
    printf 'Usage: %s HOST_OR_IP\n' "$0" >&2
    exit 2
fi

target="$1"
base_url="http://${target}:9090"

rules="$(curl --fail --silent --show-error "${base_url}/api/v1/rules")"
printf '%s' "$rules" | grep -q 'InstanceDown'
printf 'Prometheus has loaded the alert rules (InstanceDown found) on %s\n' "$base_url"
