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
# Optional env vars (installation selection, highest priority first):
#   CLAUDE_GH_APP_INSTALLATION_ID   exact installation ID to mint for
#   CLAUDE_GH_APP_OWNER             GitHub login (user or org) — installation
#                                   for that owner is resolved automatically
#
# If neither is set, the script inspects the current directory: when run
# inside a git repo with a github.com origin, it uses that repo's owner.
# As a last resort it falls back to the first installation the App has.
# That fallback is ambiguous when the App has multiple installations —
# set CLAUDE_GH_APP_OWNER explicitly to avoid surprises.
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

# Splits `curl -w \n%{http_code}` output into __body and __code.
__body=""
__code=""
split_response() {
    __body="${1%$'\n'*}"
    __code="${1##*$'\n'}"
}

extract_first_id() {
    grep -Eo '"id"[[:space:]]*:[[:space:]]*[0-9]+' \
        | head -1 \
        | grep -Eo '[0-9]+'
}

extract_token() {
    grep -Eo '"token"[[:space:]]*:[[:space:]]*"[^"]+"' \
        | head -1 \
        | sed -E 's/.*"token"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
}

# Resolve target owner from env var or current git repo
target_owner="${CLAUDE_GH_APP_OWNER:-}"
if [ -z "$target_owner" ]; then
    if git_url=$(git config --get remote.origin.url 2>/dev/null); then
        case "$git_url" in
            *github.com*)
                target_owner=$(printf '%s' "$git_url" \
                    | sed -nE 's|.*github\.com[:/]+([^/]+)/.*|\1|p')
                ;;
        esac
    fi
fi

installation_id="${CLAUDE_GH_APP_INSTALLATION_ID:-}"

# Look up installation by owner (tries /users then /orgs)
if [ -z "$installation_id" ] && [ -n "$target_owner" ]; then
    for endpoint in users orgs; do
        resp=$(api \
            -H "Authorization: Bearer $jwt" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "https://api.github.com/$endpoint/$target_owner/installation") \
            || die "network error while looking up installation for $target_owner"
        split_response "$resp"
        if [ "$__code" = "200" ]; then
            installation_id=$(printf '%s' "$__body" | extract_first_id)
            break
        fi
    done
    [ -n "$installation_id" ] \
        || die "App $CLAUDE_GH_APP_ID is not installed on $target_owner (no user or org match)"
fi

# Fallback: first installation from the global list (ambiguous if >1)
if [ -z "$installation_id" ]; then
    resp=$(api \
        -H "Authorization: Bearer $jwt" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/app/installations) \
        || die "network error while listing installations"
    split_response "$resp"
    [ "$__code" = "200" ] || die "listing installations failed (HTTP $__code): $__body"
    installation_id=$(printf '%s' "$__body" | extract_first_id)
fi

[ -n "$installation_id" ] \
    || die "no installation found for App $CLAUDE_GH_APP_ID — install the App on at least one account"

resp=$(api -X POST \
    -H "Authorization: Bearer $jwt" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/app/installations/${installation_id}/access_tokens") \
    || die "network error while minting installation token"
split_response "$resp"
[ "$__code" = "201" ] || die "minting installation token failed (HTTP $__code): $__body"

token=$(printf '%s' "$__body" | extract_token)
[ -n "$token" ] || die "token missing in installation response"

printf '%s\n' "$token"
