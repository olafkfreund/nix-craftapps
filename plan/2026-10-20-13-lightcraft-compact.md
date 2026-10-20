---
status: draft
issue: 13
spec: spec/2026-10-20-13-lightcraft-compact.md
---

# Plan: compact lightcraft MCP tool list by default

Approved decisions, carried over from the spec:

- lightcraft's MCP server defaults to `--compact` through `mcpArgs` in
  `modules/common.nix`, exactly like pdfcraft. Users restore the full list
  with `apps.lightcraft.mcp.args = [ "mcp" ];`.
- Facts checked on 2026-10-20 with lightcraft 0.9.1:
  - the full list is 388 tools (~205 KB); `--compact` lists 17 helpers
    (~18 KB);
  - every command stays reachable via `run_command {command, params}`,
    and `catalog.stats` returned its result in compact mode;
  - lightcraft has no `tool_search`.
- filmcraft and photocraft are not changed: their `--compact` only shortens
  the JSON output.
- No new option.

## Steps

1. `modules/common.nix:18-19`: after the pdfcraft entry in `mcpArgs`, add
   ```nix
   # lightcraft lists 388 tools (~205 KB); --compact lists 17 helpers, the rest via run_command.
   lightcraft = [ "--compact" ];
   ```
   → verify by
   `nix eval --raw .#checks.x86_64-linux.module.drvPath >/dev/null && echo ok`.
   Traps: no narrating comments; keep the comment to the why.

2. `flake.nix:125-128` (`module` check): after the pdfcraft assertion,
   add `&& s.lightcraft.args == [ "mcp" "--compact" ]` in the same nixfmt
   layout.
   → verify by `nix build .#checks.x86_64-linux.module`. Then the mutation
   test: comment out the step 1 entry, see the `module` check fail, and
   restore it.
   Traps: none.

3. `skills/craftapps/SKILL.md:87-92`: rename the heading "pdfcraft tool
   list" to "Compact tool lists", and rewrite the section to:
   - pdfcraft: keep the current text (`tool_search`, then `tool_call`);
   - lightcraft: started with `--compact`, which lists 17 helper tools.
     For any other command, find its id with `command_list` (or
     `list_commands`) and run it with `run_command` (`command`, `params`).
     It has no `tool_search`;
   - one closing line: for the full list, run the server without
     `--compact`.
   → verify by `wc -l skills/craftapps/SKILL.md` (≤ 150) and
   `grep -n run_command skills/craftapps/SKILL.md`.
   Traps: no versions or tool counts in the skill; it must not go stale.

4. Docs:
   - `README.md:296`: the `mcp.args` row ends "VectorCraft: `--headless`;
     PdfCraft and LightCraft: `--compact`."
   - `README.md:354-356`: rewrite it as: "PdfCraft and LightCraft list
     hundreds of tools, so the module starts both with `--compact`.
     PdfCraft then lists a core set plus `tool_search` and `tool_call`;
     LightCraft lists its helper tools and runs every other command
     through `run_command`. For the full list, set
     `programs.craftapps.apps.<app>.mcp.args = [ "mcp" ];`."
   - `llms.txt:16`: replace the PdfCraft sentence with one covering both
     apps and the same override.
   - `AGENTS.md:119-120`: "pdfcraft and lightcraft default to `--compact`
     there (163 and 388 tools otherwise)."
   → verify by `grep -n -i lightcraft README.md llms.txt AGENTS.md | grep -i compact`
   printing a line from each file.
   Traps: keep the README style plain and short.

5. Final checks, then commit as
   `feat: compact lightcraft MCP tool list by default (#13)`.
   → verify with the commands under Tests.

## Tests

```sh
python3 scripts/update.py --self-test        # self-test ok
nix fmt && git diff --stat                   # no unexpected .nix changes
nix flake check -L                           # module asserts lightcraft args; mcp runs lightcraft --compact
```

After merge, a lock bump and a deploy to p620 and razer (announced on the
agent bus, deployed from a clean worktree because `~/.config/nixos` has an
uncommitted lock change): `claude mcp list` shows
`lightcraft-cli mcp --compact` as Connected.

## Rollback

Revert the commit. lightcraft lists all 388 tools again after the next
rebuild.
