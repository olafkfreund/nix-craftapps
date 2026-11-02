---
status: draft
issue: 31
intent: intent/2026-11-02-31-craft-anything.md
---

# Spec: package Craft Anything as the 14th Craft app

## Design

Add the app the way AGENTS.md "Adding a new Craft app" says, plus two fixes
in the generic builder, because it is the first app whose name has a hyphen
and whose macOS executable is not named after its title.

Facts checked on 2026-11-02 against v0.2.0:

- **Linux tarballs** (x86_64 and aarch64): `bin/craft-anything`,
  `bin/craft-anything-cli`, `share/{applications,icons,metainfo,doc}`. This
  is the usual layout.
- **macOS:** `craft-anything-0.2.0-macos-universal.dmg` and
  `craft-anything-cli-0.2.0-macos-universal.zip`, the usual names. But
  upstream's `packaging/macos/package.sh` builds `Craft Anything.app`, with
  a space, whose executable is `Contents/MacOS/craft-anything`, the machine
  name (its comment: "The executable keeps the machine name
  (CFBundleExecutable)"). It also copies `craft-anything-cli` into
  `Contents/MacOS`, as PhotoCraft does.
- **MCP:** `craft-anything-cli mcp` answers `initialize` headless, with no
  flags. It lists 29 tools (about 30 KB): an Essentials set, with
  `list_toolsets` and `enable_toolset` for the rest. So it is already
  compact, and it needs no `mcpArgs` entry. It has no bridge flag
  (`--connect`, `--bridge` or `--attach`); `--inbox` is how it talks to the
  open app. `--allow-run`, which lets tools run code without asking, stays
  off.
- **The binary has no `ldconfig` check** and no app-specific `*_GPU*`
  switches (only wgpu's generic `WGPU_*`), so `docs/GPU.md` needs no new
  row.

### 1. Register the app

- `scripts/update.py`: add `"craft-anything": ("Craft Anything", "<one
  line>")` to `APPS`.
- Then run `python3 scripts/update.py craft-anything`, which writes the
  `apps.json` entry with all three systems.

Everything else (`default`, the overlay, the module options, MCP entries,
and the `cli` and `mcp` checks) reads `apps.json`, so it follows on its own.

### 2. Hyphen-safe variable name in `package.nix`

`${lib.toUpper name}_SKIP_LIB_CHECK` would produce
`CRAFT-ANYTHING_SKIP_LIB_CHECK`. That is not a valid shell variable name,
so the wrapper script would fail. Use
`lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] name)`, giving
`CRAFT_ANYTHING_SKIP_LIB_CHECK`. The other thirteen names have no hyphen,
so their wrappers do not change (identical `drvPath`s on Linux), and the
variable stays generic: the pattern is for "any app that copies the check
later".

### 3. Find the macOS executable from the bundle in `package.nix`

#30 wraps `${info.title}.app/Contents/MacOS/${info.title}`. That holds for
the thirteen, but here it would look for
`Craft Anything.app/Contents/MacOS/Craft Anything`, which does not exist.
Instead, read `CFBundleExecutable` from the one `.app`'s
`Contents/Info.plist`: it is what macOS itself launches. In the install
phase:

- take the single `*.app` in `$out/Applications`, quoted, because of the
  space;
- read the string after `<key>CFBundleExecutable</key>` with `sed`;
- stop the build with a clear message if it is empty, which would mean a
  binary plist or a missing key;
- `makeWrapper "$app/Contents/MacOS/$exe" $out/bin/${name}`.

This keeps one generic builder, and covers both naming styles without an
`apps.json` field.

### 4. Skill and routing rule

- `skills/craftapps/SKILL.md`:
  - add "understand how an app works or rebuild your own version → Craft
    Anything" to the `description`, keeping it at most 1,024 characters;
  - add a routing table row and a tie-breaker: Craft Anything studies an
    existing program; the other apps make files;
  - in "Bridge mode", note that it has no bridge flag.
- `skills/craftapps/routing.md`: add one short line.

### 5. Docs

- README and llms.txt: add it to the app tables.
- README, llms.txt and AGENTS.md: thirteen → fourteen.
- AGENTS.md:
  - update the macOS layout rule from #30 to say the executable comes from
    `CFBundleExecutable`;
  - note the hyphen-to-underscore change on the `SKIP_LIB_CHECK` trap;
  - rename "When storytold publishes a 14th app" to "15th".

## Alternatives rejected

- **A per-app `executable` field in `apps.json`, set through `update.py`.**
  It is more data to maintain, and it duplicates what `Info.plist` already
  says.
- **Keep the #30 rule, and fall back to `Contents/MacOS/${name}` when the
  title path is missing.** That is two guesses instead of one fact.
- **Python `plistlib` to read the plist.** It handles binary plists too, but
  adds Python to every darwin build for one value. If a binary plist ever
  shows up, the build fails loudly and we revisit this.
- **Skip the hyphen fix, because Craft Anything has no library check.** The
  invalid name breaks the wrapper itself, whatever the app does.
- **Set `--allow-run` by default.** It lets agents run code without asking.
  Leave that choice to the user, through `apps.craft-anything.mcp.args`.

## Risks

- **The plist parse fails on one of the thirteen**, for example a binary
  plist or the key and value on one line. CI's macOS runner builds all
  fourteen, so it shows up before merge. Upstream generates the plist from
  `Info.plist.in` (XML) for Craft Anything; the others are unverified until
  CI runs.
- **p620 and razer** get a new package and a `craft-anything` MCP server on
  the next lock bump. Its tool list is small, so the cost to agent context
  is low.
- **Early alpha:** an upstream layout change would break the daily update
  PR. Auto-merge leaves a failed PR open, so nothing reaches users.
- **The routing rule grows by a line** in every Claude Code session.

## Verification

- `nix flake check -L` locally on x86_64-linux: it builds all fourteen and
  runs the `cli` (`craft-anything-cli --version`), `mcp`
  (`craft-anything-cli mcp` initialize), `skill`, `module` and `hm-module`
  checks.
- The `drvPath`s of the thirteen existing Linux packages are unchanged.
- `python3 scripts/update.py --self-test` passes.
- On a real session, `timeout 8 ./result/bin/craft-anything` exits 124
  (still running), with no missing-library panic.
- CI passes on all three runners. The macOS job is the real test of steps 2
  and 3 for all fourteen bundles.
- The `skill` check passes with the new description length.
