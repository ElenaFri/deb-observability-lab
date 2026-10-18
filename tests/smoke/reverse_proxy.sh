#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 1 ]]; then
    printf 'Usage: %s HOST_OR_IP [USER] [PASSWORD]\n' "$0" >&2
    exit 2
fi

target="$1"
user="${2:-${RP_USER:-observer}}"
password="${3:-${RP_PASS:-observer}}"
base_url="https://${target}"

# The certificate is issued by Caddy's internal CA and not trusted by the client,
# so verification is intentionally skipped.

# 1. An unauthenticated request must be rejected by the proxy.
code="$(curl --insecure --silent --output /dev/null --write-out '%{http_code}' "${base_url}/api/health")"
if [[ "$code" != "401" ]]; then
    printf 'Expected 401 without credentials, got %s\n' "$code" >&2
    exit 1
fi
printf 'Unauthenticated request correctly rejected (401)\n'

# 2. An authenticated request must succeed and reach a healthy backend.
health="$(curl --insecure --fail --silent --show-error --user "${user}:${password}" "${base_url}/api/health")"
printf '%s' "$health" | grep -q '"database": *"ok"'
printf 'Authenticated request succeeded; backend healthy through the TLS proxy\n'

# 3. Plain HTTP must redirect to HTTPS.
location="$(curl --silent --output /dev/null --write-out '%{redirect_url}' "http://${target}/")"
case "$location" in
    https://*) printf 'HTTP correctly redirects to HTTPS: %s\n' "$location" ;;
    *)
        printf 'Expected HTTP to redirect to HTTPS, got: %s\n' "$location" >&2
        exit 1
        ;;
esac
