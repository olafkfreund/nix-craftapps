---
status: approved
issue: 13
intent: intent/2026-10-20-13-lightcraft-compact.md
---

# Spec: compact lightcraft MCP tool list by default

## Design

The same mechanism as pdfcraft in #10. It is one data entry plus the text
that describes it.

1. **`modules/common.nix:18-19`**: add `lightcraft = [ "--compact" ];` to
   `mcpArgs`, with a one-line why comment in the pdfcraft style: "lightcraft
   lists 388 tools (~205 KB); --compact lists 17 helpers, the rest via
   run_command." The default of `apps.lightcraft.mcp.args` becomes
   `[ "mcp" "--compact" ]`.
2. **`flake.nix:125-128`** (`module` check): add
   `s.lightcraft.args == [ "mcp" "--compact" ]` next to the pdfcraft
   assertion. The `mcp` check already runs each server with its module
   args, so lightcraft's `initialize` is tested with `--compact`.
3. **`skills/craftapps/SKILL.md:87-92`**: rename "pdfcraft tool list" to
   "Compact tool lists" and cover both apps:
   - pdfcraft: as now (`tool_search`, then `tool_call`);
   - lightcraft: the 17 helper tools are listed. For anything else, find
     the id with `command_list`/`list_commands` and run it with
     `run_command {command, params}`. lightcraft has no `tool_search`.
   - To get the full list, run without `--compact`.
4. **Docs**:
   - `README.md:296`: the `mcp.args` row gains "LightCraft: `--compact`".
   - `README.md:354-356`: the paragraph covers both apps, with each
     one's override.
   - `llms.txt:16`: the same sentence for lightcraft.
   - `AGENTS.md:119-120`: "pdfcraft and lightcraft default to
     `--compact` there (163 and 388 tools otherwise)".

Facts checked on 2026-10-20 with lightcraft 0.9.1:
- the full list is 388 tools and 205,551 bytes;
- `--compact` lists 17 tools in 18,170 bytes;
- the help says "list only the helper tools (every command stays reachable
  via run_command)";
- in compact mode, `run_command {"command":"catalog.stats"}`, a command
  not listed as a tool, returned its result with `isError: false`.

## Alternatives rejected

- **Compacting filmcraft and photocraft too**: their `--compact` only
  shortens the JSON output, not the tool list.
- **A global `mcp.compact` option**: only two apps need it, and
  `mcpArgs` already holds per-app defaults. An option would add surface
  area for no gain.
- **Leaving it to Claude Code's deferred tool loading**: other clients
  (Codex, opencode, Zed, …) load every tool up front.

## Risks

- **Agents that relied on the 371 `cmd_*` tools by name** must now go
  through `run_command`. The skill and the server's own instructions
  say how. Users can get the full list back with
  `apps.lightcraft.mcp.args = [ "mcp" ];`.
- **Bridge-mode users who set their own `mcp.args`** replace the default
  list entirely, so they decide on `--compact` themselves. Nothing
  changes for them.
- **Hosts:** p620 and razer change only after a lock bump. lightcraft's
  `~/.claude.json` entry then gains `--compact` through the existing
  reconcile.

## Verification

- The `module` check asserts lightcraft's args.
- A mutation test: removing the `mcpArgs` entry fails the `module` check.
- The `mcp` check passes, so lightcraft answers `initialize` with
  `--compact`.
- `nix flake check`, the updater's `--self-test` and `nix fmt` are clean.
  CI passes on both architectures.
- After the lock bump and deploy: `claude mcp list` shows
  `lightcraft-cli mcp --compact` as Connected.
