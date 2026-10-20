---
status: draft
issue: 16
author: olafkfreund
---

# Intent: let PhotoCraft's MCP server read and save files

## Problem

As packaged, PhotoCraft's MCP server cannot open or save any file (#16).
It denies all file access unless it is started with
`--automation-read-root` and `--automation-write-root`:

- `doc_open` on a relative path fails with "automation filesystem
  access is not granted: read authority is absent";
- on an absolute path it fails with "automation path rejected: absolute
  paths are not allowed".

The modules pass no roots, so an agent routed to PhotoCraft by #15
("remove the background from photo.png") stops at the first call.

Research on 2026-10-20, 65 probe runs across all 13 servers, found:

- Only PhotoCraft defaults to deny-all. The other 12 servers read and
  write anywhere when no roots are given.
- The root flags are not universal: cadcraft, filmcraft, gridcraft and
  lightcraft don't have them and fail to start if given one.
- A root must be an absolute path to an existing directory; `~` is not
  expanded. A root of `/` works and means "any absolute path".
- With a root set, PhotoCraft resolves relative paths against the root,
  not the working directory. Agents must pass absolute paths.

## Proposed outcome

- An agent can open and save files with PhotoCraft through MCP, given
  absolute paths, the same as with the other 12 apps.
- The skill (and the routing rule, if needed) tells agents to give
  PhotoCraft absolute paths.
- Nothing changes for the other 12 apps.

## Affected users and systems

- This flake: `mcpArgs.photocraft` in `modules/common.nix`, the
  `module` check, `skills/craftapps/SKILL.md`, and the docs.
- p620 and razer after a lock bump: PhotoCraft's entry in
  `~/.claude.json` gains the root flags.

## Constraints

- PhotoCraft gets no wider access than the other 12 servers already
  have, which is unrestricted.
- The roots must be absolute paths that exist on every machine, and must
  also work in `/etc/craftapps/mcp.json` on NixOS, where there is no
  per-user home.
- Users can still override `apps.photocraft.mcp.args`, for example to
  confine it to one folder or to use bridge mode (`--bridge` can't be
  combined with roots).

## Open questions

- Which root? Proposed: `/` for both read and write. It is one static
  `mcpArgs` entry, it works in both modules, it matches the other 12
  apps' access, and it allows `/tmp` and project folders anywhere. The
  alternative, your home directory, needs per-user values that the
  shared NixOS `mcp.json` can't hold, and it would still refuse `/tmp`.
  A suite-wide "confine every app to one folder" option is deliberately
  left out. It would be a new feature, and four apps can't take the flag.
