#!/usr/bin/env bash
# setup.sh — wire up a local machine for the Epsilon agent pattern.
#
# Prerequisites (done manually, through the GitHub web UI, before running):
#   1. Created the bot GitHub account
#   2. Registered the GitHub App under the bot account
#   3. Installed the App on the human account's repos
#   4. Downloaded the App's private key (.pem)
#
# What this script does:
#   - Installs the private key at ~/.claude/secrets/<bot>.pem (chmod 600)
#   - Installs scripts/gh-app-token.sh at ~/.claude/scripts/
#   - Appends env var exports to your shell profile (idempotent)
#   - Mints a test token to verify the wiring
#   - Prints the CLAUDE.md snippet for you to paste in by hand
#
# Safe to re-run: every step checks current state before acting.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

say() { printf '▶ %s\n' "$*"; }
ok()  { printf '✓ %s\n' "$*"; }
err() { printf '✗ %s\n' "$*" >&2; exit 1; }

for cmd in openssl curl; do
    command -v "$cmd" >/dev/null 2>&1 || err "$cmd not found in PATH"
done

printf '\n━━━ Epsilon agent: local setup ━━━\n\n'

read -r -p "GitHub App ID (numeric): " APP_ID
read -r -p "Bot GitHub username: " BOT_USER
read -r -p "Bot numeric user ID (gh api /users/$BOT_USER --jq .id): " BOT_ID
read -r -p "Path to downloaded .pem private key: " PEM_SRC

[ -n "$APP_ID" ] && [[ "$APP_ID" =~ ^[0-9]+$ ]] || err "App ID must be numeric"
[ -n "$BOT_USER" ] || err "bot username is required"
[ -n "$BOT_ID" ] && [[ "$BOT_ID" =~ ^[0-9]+$ ]] || err "bot user ID must be numeric"
PEM_SRC="${PEM_SRC/#\~/$HOME}"
[ -r "$PEM_SRC" ] || err "cannot read $PEM_SRC"

# 1. Install private key
PEM_DEST="$HOME/.claude/secrets/${BOT_USER}.pem"
mkdir -p "$(dirname "$PEM_DEST")"
chmod 700 "$(dirname "$PEM_DEST")"
cp "$PEM_SRC" "$PEM_DEST"
chmod 600 "$PEM_DEST"
ok "installed private key at $PEM_DEST (chmod 600)"

# 2. Install token helper
SCRIPT_SRC="$ROOT_DIR/scripts/gh-app-token.sh"
SCRIPT_DEST="$HOME/.claude/scripts/gh-app-token.sh"
[ -r "$SCRIPT_SRC" ] || err "cannot find $SCRIPT_SRC — run this from a checkout of epsilon-agent"
mkdir -p "$(dirname "$SCRIPT_DEST")"
cp "$SCRIPT_SRC" "$SCRIPT_DEST"
chmod +x "$SCRIPT_DEST"
ok "installed token helper at $SCRIPT_DEST"

# 3. Append env var exports to shell profile (idempotent)
PROFILE="${EPSILON_SHELL_PROFILE:-$HOME/.zshrc}"
touch "$PROFILE"
if grep -q 'CLAUDE_GH_APP_ID' "$PROFILE"; then
    say "CLAUDE_GH_APP_ID already present in $PROFILE — leaving it alone"
else
    {
        printf '\n'
        printf '# ── Epsilon agent — GitHub App credentials ──────────────────────────────────\n'
        printf '# See https://github.com/amcheste-ai-agent/epsilon-agent for context\n'
        printf 'export CLAUDE_GH_APP_ID="%s"\n' "$APP_ID"
        # shellcheck disable=SC2016  # $HOME is meant to be literal in the written profile
        printf 'export CLAUDE_GH_APP_PRIVATE_KEY_PATH="$HOME/.claude/secrets/%s.pem"\n' "$BOT_USER"
    } >>"$PROFILE"
    ok "appended env vars to $PROFILE"
fi

# 4. Smoke test
export CLAUDE_GH_APP_ID="$APP_ID"
export CLAUDE_GH_APP_PRIVATE_KEY_PATH="$PEM_DEST"
say "minting a test installation token..."
if TOKEN=$("$SCRIPT_DEST" 2>&1); then
    ok "token minted successfully (${#TOKEN} chars, prefix: ${TOKEN:0:4})"
else
    err "token mint failed:
$TOKEN"
fi

# 5. Print CLAUDE.md snippet for the user
BOT_NOREPLY="${BOT_ID}+${BOT_USER}@users.noreply.github.com"

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Next step: add the section below to ~/.claude/CLAUDE.md so Claude Code
knows to commit as the bot and use installation tokens for GitHub writes.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Git and GitHub Identity

Claude commits and pushes as the bot account \`${BOT_USER}\`, not as you.
This keeps the audit trail clean — AI-authored and human-authored commits
stay distinguishable at a glance.

### Commits

- Every commit must set \`--author\`:
    git commit --author="${BOT_USER} <${BOT_NOREPLY}>" ...
- Every commit message must end with a Co-Authored-By trailer naming the
  specific Claude model producing the commit:
    Co-Authored-By: Claude <noreply@anthropic.com>

### Pushing to GitHub

Before any \`git push\`, \`gh pr create\`, or other \`gh\` write, mint a
fresh installation token:
    export GH_TOKEN=\$(~/.claude/scripts/gh-app-token.sh)

### Never

- Commit the private key (\`$PEM_DEST\`) to any repo.
- Echo, log, or otherwise surface \$GH_TOKEN.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

ok "setup complete — reload your shell or run: source \"$PROFILE\""
