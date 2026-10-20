---
status: draft
issue: 8
author: olafkfreund
---

# Intent: merge daily update PRs automatically once CI passes

## Problem

The `update` workflow runs daily and opens `chore: update Craft apps`, but
the update never reaches `main` without a person (#8):

- GitHub holds the `pull_request` CI run on the bot's PR at "approve and
  run". Run 39204754225 is still waiting; you approved 39375052810 by hand.
  That run duplicates the CI that `update.yml` already dispatches.
- Nobody merges the PR. #7 sat green on both architectures for two days.

## Proposed outcome

A day with new upstream releases ends with them on `main`, with no clicks:
the update PR merges itself, and its branch is deleted, after the
dispatched CI passes on x86_64 and aarch64. A failing CI leaves the PR open
for a person.

## Affected users and systems

- `.github/workflows/ci.yml` (and possibly `update.yml`) in this repo.
- Consumers following `main` get new app versions a day sooner; nothing
  changes for consumers pinned by lock.

## Constraints

- Merge only after CI passes on both architectures (AGENTS.md).
- Only the bot's `update/craft-apps` branch auto-merges; feature PRs never do.
- No new secrets if avoidable, so no PAT or GitHub App.
- GUIs are not launched before merge. The flake checks (build, cli, mcp,
  modules) are the gate. You accepted this trade-off on 2026-10-20.

## Open questions

None.
