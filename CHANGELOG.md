# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- MIT `LICENSE`; the repo was pitched as a reference implementation but was unlicensed (all rights reserved), so nobody could legally reuse it.
- `SECURITY.md` with the standard 7-day acknowledge / 30-day resolve policy, plus a scope note pointing at the private-key security boundary.
- `.github/CODEOWNERS` routing every PR to @amcheste. This re-lands the content of PR #2, whose merge commit was lost to a force-push of `develop` on 2026-04-24.
- CI baseline per the [engineering handbook](https://github.com/amcheste/engineering-handbook): `validate.yml` (shellcheck over `scripts/` and `setup/`, markdownlint, offline link check, commit lint, semver suggestion), `gitleaks.yml` secret-scan backstop, `sast.yml` (Semgrep `p/secrets` + `p/bash`), `scorecard.yml`, and `stale.yml`.
- Gitleaks pre-commit hook config (`.pre-commit-config.yaml`); install once with `pre-commit install`.

### Changed

- `scripts/gh-app-token.sh` now resolves which installation to mint against in this order: `CLAUDE_GH_APP_INSTALLATION_ID`, `CLAUDE_GH_APP_OWNER`, the owner of the current git repo's `origin` remote, and finally the first installation the App has (unchanged fallback). Fixes the ambiguity when the App is installed on more than one account.

## [0.1.0] - 2026-04-24

### Added

- Initial reference implementation of the Epsilon agent pattern.
- `scripts/gh-app-token.sh` — mint short-lived GitHub App installation tokens.
- `setup/` — bootstrap tooling (`setup.sh`, `app-manifest.json`, walkthrough) for replicating the pattern on a new machine and a new bot account.
- README covering ownership model, security boundary, and pointer to the engineering-handbook design doc.

[Unreleased]: https://github.com/amcheste-ai-agent/epsilon-agent/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/amcheste-ai-agent/epsilon-agent/releases/tag/v0.1.0
