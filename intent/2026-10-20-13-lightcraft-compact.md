---
status: draft
issue: 13
author: olafkfreund
---

# Intent: compact lightcraft MCP tool list by default

## Problem

lightcraft's MCP server lists 388 tools, about 205 KB of `tools/list`
(lightcraft 0.9.1, measured 2026-10-20). That is more than pdfcraft's 163
tools, which #10 already compacted. Every agent with the Craft servers
pays that context cost at startup, and clients without deferred tool
loading pay all of it (#13).

`lightcraft-cli mcp --compact` lists only the 17 helper tools (about
18 KB): `command_list`, `command_run`, `command_batch`, `doc_inspect`,
`render_preview`, `set_develop`, `export` and so on. Its help says
"every command stays reachable via `run_command`".

## Proposed outcome

- The packaged lightcraft MCP server starts with `--compact`. Users can
  restore the full list with `apps.lightcraft.mcp.args = [ "mcp" ];`.
- The `craftapps` skill tells agents that lightcraft's other commands
  are reached through `command_list` and `run_command`. Unlike
  pdfcraft's compact mode, lightcraft has no `tool_search`.
- Docs mention the default and how to undo it, next to pdfcraft's.

## Affected users and systems

- This flake: `modules/common.nix` (`mcpArgs`), `flake.nix` (the
  module check), `skills/craftapps/SKILL.md`, README, llms.txt and
  AGENTS.md.
- p620 and razer after a lock bump: lightcraft's entry in
  `~/.claude.json` gains `--compact` through the existing reconcile.

## Constraints

- Same mechanism as pdfcraft: one `mcpArgs` entry, no per-app branches.
- filmcraft and photocraft also have a `--compact` flag, but it only
  shortens JSON output, so they are out of scope.
- The `mcp` check must still pass with `--compact`.

## Open questions

None.
