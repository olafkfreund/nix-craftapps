---
status: approved
issue: 16
intent: intent/2026-10-20-16-photocraft-roots.md
---

# Spec: let PhotoCraft's MCP server read and save files

The intent was approved with its open question answered as proposed:
the root is `/` for both read and write.

## Design

1. **`modules/common.nix:16-22`** (`mcpArgs`): add

   ```nix
   # photocraft denies all file access without roots; / matches the other servers, which are unrestricted.
   photocraft = [ "--automation-read-root" "/" "--automation-write-root" "/" ];
   ```

   `apps.photocraft.mcp.args` then defaults to
   `[ "mcp" "--automation-read-root" "/" "--automation-write-root" "/" ]`
   in both modules and in `/etc/craftapps/mcp.json`.
2. **`flake.nix`** (`module` check, next to the lightcraft assertion):
   assert `s.photocraft.args` equals that list. The `mcp` check already
   starts every server with its module args, so it proves PhotoCraft
   starts with the roots.
3. **Absolute paths**, because with a root set PhotoCraft resolves
   relative paths against the root, which is `/`:
   - `skills/craftapps/routing.md:6`: "… .psd → photocraft (absolute
     paths)";
   - `skills/craftapps/SKILL.md` "File access roots": one sentence. The
     packaged PhotoCraft server is rooted at `/`, so give it absolute
     paths; relative ones resolve against `/`.
4. **Docs:**
   - README `mcp.args` row (line ~296): "PhotoCraft: file roots `/`";
   - AGENTS.md MCP trap: PhotoCraft denies file access without roots,
     so `mcpArgs` roots it at `/`. Root flags must not be combined
     with `--bridge`, and cadcraft, filmcraft, gridcraft and lightcraft
     reject them;
   - llms.txt: one sentence.

Facts this relies on, from 65 probe runs on 2026-10-20:
- `/` is accepted as a root;
- with it, an absolute open and an absolute save both succeed;
- without roots, both fail.

## Alternatives rejected

- **The home directory as root**: the shared NixOS `mcp.json` has no
  per-user value, `~` isn't expanded, and it would still refuse `/tmp`.
- **A suite-wide `mcp.fileRoot` option**: a new feature, not a fix. Four
  apps reject the flag, seven reject a repeated flag, and EffectCraft
  then refuses relative paths.
- **Documenting the override only**: PhotoCraft stays broken out of the
  box, and the routing from #15 sends agents straight into that failure.

## Risks

- **PhotoCraft's agent access widens from nothing to anything.** That is
  equal to the other 12 servers today, and the agent already has a
  shell. Users who want confinement set `apps.photocraft.mcp.args`.
- **Users who set `apps.photocraft.mcp.args` themselves**, for example to
  `--bridge`, replace the whole list. Nothing changes for them, and bridge
  mode must not carry roots.
- **Agents that pass relative paths** get "not found" under `/`. The
  routing rule and the skill say to use absolute paths.

## Verification

- The `module` check asserts the args. A mutation test (removing the
  entry) fails it.
- The `mcp` check passes, so PhotoCraft starts with the roots.
- A headless MCP probe: `doc_open` of an absolute path to a PNG, then
  `doc_save` (or export) to an absolute path, both succeed with the
  packaged args.
- A real `claude -p` run of "Remove the background from /abs/path/photo.png
  and save it as /abs/path/photo-cut.png", with the new routing rule,
  creates the file using `mcp__photocraft__` tools.
- `nix flake check`, the updater's `--self-test` and `nix fmt` are clean.
  CI passes on both architectures. Then a nixos-config lock bump and a
  deploy, announced on the agent bus.
