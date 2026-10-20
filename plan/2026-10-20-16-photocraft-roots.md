---
status: approved
issue: 16
spec: spec/2026-10-20-16-photocraft-roots.md
---

# Plan: let PhotoCraft's MCP server read and save files

Approved decisions, carried over from the spec:

- PhotoCraft's server denies all file access unless it is started with
  roots. The packaged args get
  `--automation-read-root / --automation-write-root /`, which matches the
  other 12 servers; those are unrestricted by default.
- It is one static `mcpArgs` entry, so it applies to Home Manager,
  NixOS, nix-darwin (#18) and `/etc/craftapps/mcp.json` alike. No new
  option.
- With the root at `/`, PhotoCraft resolves relative paths against `/`,
  so agents must pass absolute paths. The routing rule and the skill say
  so.
- Root flags must not be combined with `--bridge`. cadcraft, filmcraft,
  gridcraft and lightcraft reject the flags; they are not touched.
- Facts verified on 2026-10-20 (65 probe runs): `/` is accepted as a
  root; with it, an absolute open and an absolute save both succeed;
  without roots, both fail.

## Steps

1. `modules/common.nix:16-22` (`mcpArgs`): after the lightcraft entry,
   add

   ```nix
   # photocraft denies all file access without roots; / matches the other servers, which are unrestricted.
   photocraft = [ "--automation-read-root" "/" "--automation-write-root" "/" ];
   ```

   `nix fmt` may split the list.
   → verify by
   `nix eval --raw .#checks.x86_64-linux.module.drvPath >/dev/null && echo ok`.
   Traps: no narrating comments.

2. `flake.nix:156-159` (`module` check): after the lightcraft assertion,
   add
   `&& s.photocraft.args == [ "mcp" "--automation-read-root" "/" "--automation-write-root" "/" ]`.
   → verify by `nix build .#checks.x86_64-linux.module`. Mutation test,
   from a scratchpad backup: remove the step 1 entry, the check must
   fail; restore it and the check must pass.
   Traps: don't use `git checkout` to restore.

3. Agent text:
   - `skills/craftapps/routing.md:6`: change "… .psd → photocraft" to
     "… .psd → photocraft (absolute paths)". Keep the file under 1000
     bytes.
   - `skills/craftapps/SKILL.md`: at the end of the "File access roots"
     section (line 113), add "The packaged PhotoCraft server is rooted at
     `/`, so give it absolute paths; a relative path resolves against
     `/`."
   → verify by `wc -c skills/craftapps/routing.md` (≤ 1000) and
   `nix build .#checks.x86_64-linux.skill`.
   Traps: the `skill` check parses only the frontmatter; the body is
   free text.

4. Docs:
   - `README.md:343`: the `mcp.args` row ends "…; PhotoCraft: file roots
     `/`."
   - `AGENTS.md:139-140` (MCP trap): append "photocraft denies all file
     access without roots, so it gets `--automation-read-root /
     --automation-write-root /` there. Root flags can't be combined with
     `--bridge`, and cadcraft, filmcraft, gridcraft and lightcraft reject
     them."
   - `llms.txt:16`: append "PhotoCraft's server is rooted at `/` so it can
     read and save files; give it absolute paths."
   → verify by `grep -n 'automation-read-root\|rooted at' README.md AGENTS.md llms.txt`.
   Traps: plain, short wording.

5. Real tests, with no repo edits:
   - **Headless MCP probe.** In a scratch dir, make a PNG with a flat
     background, for example with
     `nix shell nixpkgs#imagemagick -c magick -size 64x64 xc:white -fill red -draw 'circle 32,32 32,16' in.png`.
     Run `photocraft-cli mcp --automation-read-root / --automation-write-root /`
     with HOME set to a temp dir. Over stdin send initialize,
     `notifications/initialized`, `doc_open` with the absolute path, then
     `doc_save` or `doc_export` to an absolute `out.png`. Both must
     succeed, and `out.png` must exist.
   - **Real Claude Code.** In a fresh scratch dir with `photo.png` and
     the repo's `routing.md` as `.claude/rules/craftapps.md`, add a
     project `.mcp.json` server named `photocraft-rooted` that uses the
     new args. The globally installed `photocraft` entry still has no
     roots until the deploy. Run `claude -p` (prompt on stdin,
     `timeout 600`) with "Remove the background from <abs>/photo.png and
     save it as <abs>/photo-cut.png". Allow `mcp__photocraft-rooted__*`
     and `Skill`.
   - **Pass:** the `photo-cut.png` file exists and the
     `mcp__photocraft-rooted__` tools were used. If the agent picks the
     unrooted global `photocraft` server first and fails, note it: that
     ends after the deploy.
   → verify by the two pass results.
   Traps: never launch the GUI; don't edit `~/.claude`.

6. Final checks and commit as
   `fix: let PhotoCraft's MCP server read and save files (#16)`.
   → verify with the commands under Tests.

## Tests

```sh
python3 scripts/update.py --self-test        # self-test ok
nix fmt && git diff --stat                   # no unexpected .nix changes
nix flake check -L                           # module asserts photocraft args; mcp starts photocraft with roots
```

CI must pass on all three runners (x86_64, aarch64, macOS). After merge:
bump the lock in nixos-config, which also brings #18. Build p620 and
razer, deploy from a clean worktree announced on the agent bus, and check
that `claude mcp list` shows PhotoCraft with the roots as Connected.
Close #16.

## Rollback

Revert the commit. PhotoCraft goes back to having no file access.

## Deviations

- Step 4: AGENTS.md no longer says root flags "can't be combined with
  `--bridge`". Review could not confirm that for PhotoCraft. It now says
  what the research showed: a bridged app enforces its own roots, so drop
  them when switching to `--connect`, `--attach` or `--bridge`.
- Step 5: the Claude Code run used `--strict-mcp-config`, so only the
  rooted test server was loaded.
