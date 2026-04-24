# Epsilon

Epsilon is a personal AI coding agent built on Claude Code. It commits code,
opens pull requests, and maintains a clean audit trail separating AI-authored
work from human-authored work.

Named after the ε in epsilon-delta proofs — sweating the details so the
proof holds.

## How it works

- Code is authored by Claude, committed under a dedicated bot account
- The human reviews and approves all PRs via CODEOWNERS
- A GitHub App owned by the bot account handles authentication — no
  long-lived PATs anywhere
- Short-lived installation tokens are minted per session and never written
  to disk
- The private key (`.pem`) is the only secret. It lives on disk with
  `chmod 600` and never touches a repo.

## Ownership model

The bot account owns its own GitHub App and credentials. The human account
grants the App access to its repos. Neither bleeds into the other's domain.

This separation is intentional. It makes the audit trail clean, the security
boundary clear, and the pattern easy to reason about.

```
  ┌─────────────────────┐                     ┌─────────────────────┐
  │  amcheste-ai-agent  │                     │      amcheste       │
  │     (the bot)       │                     │    (the human)      │
  ├─────────────────────┤                     ├─────────────────────┤
  │ owns GitHub App     │                     │ installs the App on │
  │ holds private key   │ ───── grants ─────▶ │ their own repos     │
  │ commits as author   │                     │ reviews every PR    │
  └─────────────────────┘                     └─────────────────────┘
```

## Using this pattern yourself

This repo is a reference implementation. **Do not install this App** —
create your own. Each person running this pattern should own their own
bot account, their own GitHub App, and their own private key.

See [`setup/`](setup/) for a step-by-step walkthrough. At the end you'll
have a fully self-contained instance with no dependency on
`amcheste-ai-agent`.

## Repository layout

```
epsilon-agent/
├── scripts/
│   └── gh-app-token.sh    Mint a short-lived installation token for the App
├── setup/
│   ├── README.md          How to set up your own instance of this pattern
│   ├── setup.sh           Local-machine bootstrap script
│   └── app-manifest.json  GitHub App manifest template for registration
├── CHANGELOG.md
├── VERSION
└── README.md
```

## The private key is the security boundary

The GitHub App ID and client ID are public — they appear on the App's
settings page and in commit metadata. That's fine. Without the App's
private key (the `.pem` file), nobody can mint tokens for the App, and
without a token nobody can write to the repos the App is installed on.

Keep the `.pem`:

- On disk at `~/.claude/secrets/` with `chmod 600`
- Out of any git repo (see [.gitignore](.gitignore))
- Off of chat logs, screenshots, and paste buffers

If you suspect the key is compromised, regenerate it from the App's
settings page and replace the file. The previous key becomes useless
the moment the new one is issued.

## Design doc

Full design rationale and alternatives considered:
[engineering-handbook/docs/design/claude-bot-account.md](https://github.com/amcheste/engineering-handbook/blob/develop/docs/design/claude-bot-account.md)
