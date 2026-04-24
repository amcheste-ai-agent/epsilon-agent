#!/usr/bin/env bash
# gh-app-token.sh — mint a short-lived GitHub App installation token.
#
# Why this exists:
#   Epsilon (amcheste-ai-agent) authenticates to GitHub as its own App rather
#   than using a long-lived PAT. Installation tokens expire within an hour,
#   so we mint a fresh one per session and keep the App's private key as the
#   only persistent secret. Tokens are printed to stdout — never written to
#   disk, never echoed into shell history, never baked into env files.
#
# Usage:
#   export GH_TOKEN=$(~/.claude/scripts/gh-app-token.sh)
#   gh pr create ...
#
# Required env vars:
#   CLAUDE_GH_APP_ID                numeric GitHub App ID
#   CLAUDE_GH_APP_PRIVATE_KEY_PATH  path to the App's .pem private key
#
# Dependencies: bash, openssl, curl. No Python, Node, or jq required.

set -euo pipefail

die() { printf 'gh-app-token: %s\n' "$*" >&2; exit 1; }

: "${CLAUDE_GH_APP_ID:?CLAUDE_GH_APP_ID is not set — see ~/.zshrc}"
: "${CLAUDE_GH_APP_PRIVATE_KEY_PATH:?CLAUDE_GH_APP_PRIVATE_KEY_PATH is not set — see ~/.zshrc}"

[ -r "$CLAUDE_GH_APP_PRIVATE_KEY_PATH" ] \
    || die "cannot read private key at $CLAUDE_GH_APP_PRIVATE_KEY_PATH"

for cmd in openssl curl; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd not found in PATH"
done

b64url() {
    openssl base64 -A | tr '+/' '-_' | tr -d '='
}

now=$(date +%s)
iat=$((now - 60))
exp=$((now + 600))

header_b64=$(printf '%s' '{"alg":"RS256","typ":"JWT"}' | b64url)
payload_b64=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$iat" "$exp" "$CLAUDE_GH_APP_ID" | b64url)
unsigned="${header_b64}.${payload_b64}"

signature=$(printf '%s' "$unsigned" \
    | openssl dgst -sha256 -sign "$CLAUDE_GH_APP_PRIVATE_KEY_PATH" \
    | b64url) \
    || die "failed to sign JWT — check that the private key matches App $CLAUDE_GH_APP_ID"

jwt="${unsigned}.${signature}"

api() {
    curl -sS -w $'\n%{http_code}' "$@"
}

parse_response() {
    local response="$1" expected="$2" description="$3"
    local http_code="${response##*$'\n'}"
    local body="${response%$'\n'*}"
    if [ "$http_code" != "$expected" ]; then
        die "$description failed (HTTP $http_code): $body"
    fi
    printf '%s' "$body"
}

installations_response=$(api \
    -H "Authorization: Bearer $jwt" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/app/installations) \
    || die "network error while listing installations"

installations_body=$(parse_response "$installations_response" "200" "listing installations")

installation_id=$(printf '%s' "$installations_body" \
    | grep -Eo '"id"[[:space:]]*:[[:space:]]*[0-9]+' \
    | head -1 \
    | grep -Eo '[0-9]+')

[ -n "${installation_id:-}" ] \
    || die "no installation found for App $CLAUDE_GH_APP_ID — install the App on at least one account"

token_response=$(api -X POST \
    -H "Authorization: Bearer $jwt" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/app/installations/${installation_id}/access_tokens") \
    || die "network error while minting installation token"

token_body=$(parse_response "$token_response" "201" "minting installation token")

token=$(printf '%s' "$token_body" \
    | grep -Eo '"token"[[:space:]]*:[[:space:]]*"[^"]+"' \
    | head -1 \
    | sed -E 's/.*"token"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')

[ -n "${token:-}" ] || die "token missing in installation response"

printf '%s\n' "$token"
