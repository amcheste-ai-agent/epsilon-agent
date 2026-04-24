# Setup: run your own Epsilon agent

This directory contains everything you need to stand up your own instance
of the Epsilon pattern — your own bot account, your own GitHub App, your
own private key. Nothing you create here should depend on
`amcheste-ai-agent`'s App in any way.

## Prerequisites

- A GitHub account for the human reviewer (yours)
- A second GitHub account for the bot (you will create this below)
- `bash`, `openssl`, `curl`, and [`gh`](https://cli.github.com/) installed
- [Claude Code](https://docs.claude.com/claude-code) installed and working

## Step 1 — Create the bot account

Sign up for a new GitHub account using an email alias or a dedicated
address. Pick a username that makes the bot's role obvious:
`<your-handle>-ai-agent`, `<your-handle>-bot`, or similar.

Turn on two-factor authentication for the bot account before anything else.

## Step 2 — Register the GitHub App

While logged in to GitHub **as the bot account**:

1. Go to https://github.com/settings/apps/new
2. Use [`app-manifest.json`](app-manifest.json) as a starting point for the
   permissions and metadata. Edit the `name`, `url`, and `redirect_url`
   fields before submitting.
3. Leave the App **public** — this is fine. The security boundary is the
   private key, not App visibility.
4. After registering, GitHub shows the numeric **App ID**. Save it.
5. Generate a **private key**. GitHub will download a `.pem` file. This is
   your only copy — treat it like an SSH private key.

Note the bot's numeric user ID (you will need it for commit authoring):

```bash
gh api /users/<bot-username> --jq '.id'
```

## Step 3 — Install the App on the human account

Switch back to the **human account** and install the App on the repos you
want the bot to work in. Grant at minimum:

- `Contents: Read & write`
- `Pull requests: Read & write`
- `Metadata: Read-only`

Add `Issues: Write` and `Workflows: Write` if you want the bot to manage
those surfaces too.

## Step 4 — Wire it up locally

Run the bootstrap script from the repo root:

```bash
bash setup/setup.sh
```

It will ask for your App ID, bot username, bot user ID, and the path to
the downloaded `.pem`. It then:

1. Installs the private key at `~/.claude/secrets/<bot-username>.pem`
   (`chmod 600`)
2. Installs the token helper at `~/.claude/scripts/gh-app-token.sh`
3. Appends the required env vars to your shell profile (idempotent)
4. Mints a test token to verify everything works
5. Prints the `CLAUDE.md` snippet you should add to
   `~/.claude/CLAUDE.md`

## Step 5 — Tell Claude Code who to commit as

Paste the snippet from step 4's output into `~/.claude/CLAUDE.md`. The
key rules it encodes:

- Commits set `--author` to the bot identity
- Commits include a `Co-Authored-By: Claude <noreply@anthropic.com>`
  trailer (with the actual model version)
- Before any `gh` command that writes to GitHub, mint a fresh token:

  ```bash
  export GH_TOKEN=$(~/.claude/scripts/gh-app-token.sh)
  ```

## Step 6 — Verify

From a shell with the env vars loaded:

```bash
export GH_TOKEN=$(~/.claude/scripts/gh-app-token.sh)
gh api /installation/repositories --jq '.repositories[].full_name'
```

You should see the repos the App is installed on. If you do, the
bootstrap is complete.

## What's where, after setup

| Path | Purpose |
|------|---------|
| `~/.claude/secrets/<bot-username>.pem` | The App's private key (the real secret) |
| `~/.claude/scripts/gh-app-token.sh` | Mints installation tokens on demand |
| `~/.claude/CLAUDE.md` | Tells Claude Code to commit as the bot |
| `~/.zshrc` (or equivalent) | Exports `CLAUDE_GH_APP_ID` and `CLAUDE_GH_APP_PRIVATE_KEY_PATH` |
