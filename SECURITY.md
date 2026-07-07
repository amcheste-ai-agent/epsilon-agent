# Security Policy

## Supported Versions

Only the latest release is actively maintained.

## Reporting a Vulnerability

**Please do not open a public issue for security vulnerabilities.**

Use GitHub's [private vulnerability reporting](https://github.com/amcheste-ai-agent/epsilon-agent/security/advisories/new) to report issues confidentially.

Please include:

- A clear description of the vulnerability
- Steps to reproduce
- Potential impact

You can expect an acknowledgement within **7 days** and a resolution or status update within **30 days**.

## Scope note

The security boundary of this pattern is the GitHub App's private key; see the [README](README.md#the-private-key-is-the-security-boundary). Reports about token handling, key exposure paths, or scope escalation in `scripts/gh-app-token.sh` and `setup/setup.sh` are especially welcome.
