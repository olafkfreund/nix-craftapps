---
status: approved
issue: 31
author: olafkfreund
---

# Intent: package Craft Anything as the 14th Craft app

## Problem

storytold publishes a 14th app, Craft Anything, at `storytold/craft-anything`
(<https://getartcraft.com/apps/craft-anything>). It helps you study how a
piece of software works and build your own version with a coding agent, and
it has a headless CLI and an MCP server. This flake packages only thirteen
apps, so Craft Anything users get no package, no
`programs.craftapps.apps.craft-anything` switch, no MCP server entry and no
daily updates (#31).

## Proposed outcome

- `nix build .#craft-anything` works on x86_64-linux, aarch64-linux and
  aarch64-darwin, and `default` includes it.
- `programs.craftapps.apps.craft-anything.enable` exists in the NixOS,
  nix-darwin and Home Manager modules and follows `enableAll` like the
  others.
- With `mcp.enable`, its MCP server (`craft-anything-cli mcp`) is configured
  like the other apps, if it answers headless.
- The craftapps skill and the Claude Code routing rule send "study how an
  app works / rebuild an app" requests to it.
- The daily update workflow keeps it current.
- README, llms.txt and AGENTS.md say fourteen apps and list it.

## Affected users and systems

- This flake: `scripts/update.py` (APPS table), `apps.json` (written by the
  updater), `package.nix`, `skills/craftapps/`, docs.
- Every consumer with `enableAll = true`, including the user's nixos-config
  on p620 and razer: Craft Anything installs on their next lock bump, and
  with `mcp.enable` a `craft-anything` server is added to `~/.claude.json`.

## Constraints

- Follow AGENTS.md "Adding a new Craft app": the `apps.json` entry comes
  from `update.py`, never by hand.
- One generic builder: no per-app branch in `package.nix`. The v0.2.0 Linux
  tarball has the usual layout (`bin/craft-anything`,
  `bin/craft-anything-cli`, `share/{applications,icons,metainfo,doc}`), and
  macOS has `craft-anything-0.2.0-macos-universal.dmg` plus
  `craft-anything-cli-0.2.0-macos-universal.zip`, checked on 2026-11-02.
- First app whose name has a hyphen. The wrapper's
  `${lib.toUpper name}_SKIP_LIB_CHECK` would become
  `CRAFT-ANYTHING_SKIP_LIB_CHECK`, which is not a valid variable name, so
  the generic code must handle it for every app, not by special-casing this
  one.
- The skill `description` must stay under 1,024 characters (the `skill`
  check).
- CI must pass on all three runners before merge.
- The modules must not set any `hardware.*` option.
- It is early alpha (0.2.0); expect frequent releases, which the daily
  update already handles.

## Open questions

- The DMG's `.app` and executable name (`Craft Anything.app`, with a space,
  or `CraftAnything.app`) decides whether the darwin install phase from #30
  (`${info.title}.app/Contents/MacOS/${info.title}`) works as is. The spec
  checks it.
- Bumping nixos-config's lock to put it on p620 and razer is a separate
  change. Do it after this merges, as before?
