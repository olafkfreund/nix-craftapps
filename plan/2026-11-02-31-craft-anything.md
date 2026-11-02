---
status: approved
issue: 31
spec: spec/2026-11-02-31-craft-anything.md
---

# Plan: package Craft Anything as the 14th Craft app

Approved decisions, carried over from the spec:

- **App id `craft-anything`, title "Craft Anything".** `update.py` writes
  the `apps.json` entry for all three systems; it is never hand-edited.
  Everything else (packages, `default`, overlay, module options, MCP
  entries, the `cli` and `mcp` checks) follows from `apps.json`.
- **No `mcpArgs` entry.** `craft-anything-cli mcp` answers headless with no
  flags and lists 29 tools (about 30 KB). `--allow-run` stays off. The app
  has no bridge flag (`--inbox` is how it talks to the open app).
- **Hyphen-safe variable:** `${lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ]
  name)}_SKIP_LIB_CHECK`, giving `CRAFT_ANYTHING_SKIP_LIB_CHECK`. The other
  thirteen are unchanged.
- **macOS executable from `CFBundleExecutable`** in the single `.app`'s
  `Contents/Info.plist`, read with `sed`. The build fails loudly if it
  can't be read. This replaces #30's `${info.title}` path; Craft Anything
  ships `Craft Anything.app` whose executable is `craft-anything`.
- **Routing:** "understand how an app works or rebuild your own version →
  Craft Anything" in the skill description (at most 1,024 characters; 908
  now), the routing table, a tie-breaker, the bridge table, and one line in
  `routing.md`.
- **Docs:** thirteen → fourteen, the app tables, and the AGENTS.md rules for
  the macOS layout and `SKIP_LIB_CHECK`. No `docs/GPU.md` change: the
  binary has only wgpu's generic `WGPU_*` switches.
- Out of scope: the nixos-config lock bump (separate, after merge).

## Steps

1. `scripts/update.py:18-32` (`APPS`): add, in alphabetical order after
   `"cadcraft"`:
   `"craft-anything": ("Craft Anything", "study how software works and craft your own version"),`.
   Then run `python3 scripts/update.py craft-anything`.
   → Verify: `apps.json` has `craft-anything` with `x86_64-linux`,
   `aarch64-linux` and `aarch64-darwin` (with `cli`) at 0.2.0 or later;
   `nix build .#craft-anything` succeeds with autoPatchelf reporting
   `0 dependencies could not be satisfied`;
   `./result/bin/craft-anything-cli --version` prints the version.
   Traps:
   - Never hand-edit versions or hashes in `apps.json`.
   - The updater refuses a release that lacks a system, which is fine
     here: v0.2.0 has all three.

2. `package.nix:65` (Linux `postFixup`): replace `${lib.toUpper name}` with
   `${lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] name)}`. Keep the
   comment above it.
   → Verify:
   - `nix eval --raw .#photocraft.drvPath` (and any two others) is the
     same before and after, so the thirteen are unchanged;
   - `grep SKIP_LIB_CHECK result/bin/craft-anything` shows
     `CRAFT_ANYTHING_SKIP_LIB_CHECK`.
   Traps:
   - One generic builder: no `if name == …`.
   - The wrapper must still set it for every app (AGENTS.md
     "PhotoCraft's own library check").

3. `package.nix:85-93` (darwin `installPhase`): replace the two comment
   lines and the `makeWrapper` line with:

   ```sh
   app=$(echo $out/Applications/*.app)
   # The executable is CFBundleExecutable: PhotoCraft's matches its title,
   # Craft Anything's is the machine name, and Contents/MacOS may hold the CLI too.
   exe=$(sed -n '/<key>CFBundleExecutable<\/key>/{n;s/.*<string>\(.*\)<\/string>.*/\1/p;}' "$app/Contents/Info.plist")
   [ -n "$exe" ] || { echo "no CFBundleExecutable in $app/Contents/Info.plist" >&2; exit 1; }
   makeWrapper "$app/Contents/MacOS/$exe" $out/bin/${name}
   ```

   `echo` with the glob gives one path, space included, because there is
   one `.app` per DMG (AGENTS.md layout rule). Quote `$app` everywhere.
   → Verify:
   - `nix flake check --all-systems --no-build` evaluates;
   - `nix eval --raw .#packages.aarch64-darwin.craft-anything.drvPath`
     succeeds;
   - the real test is CI's macOS job, which builds all fourteen.
   Traps:
   - `dontFixup` stays: no stripping or re-signing.
   - Use `makeWrapper`, not a symlink: the bundle must be launched by path
     inside the `.app`.
   - Never patch or re-sign the bundles.

4. Skill files.
   - `skills/craftapps/SKILL.md:3` (`description`): before " Also for
     driving", add
     `understand how an app or program works, or rebuild your own version of it → Craft Anything;`
     (change the preceding `→ SoundCraft.` to `→ SoundCraft;` and end the
     new clause with `.`).
     - No `<`, `>` or `"` in the description.
     - Keep it at most 1,024 characters.
   - `skills/craftapps/SKILL.md:21-35` (routing table): add the row
     `| how an existing app works, rebuild it | craft-anything | a target program, folder or URL (absolute path) | evidence, reports, project folder (*.cany) |`.
   - `skills/craftapps/SKILL.md:38-53` ("When two apps fit"): add the
     bullet
     `- **Study vs make:** understanding or re-creating an existing program → craft-anything. Making a file → the app for that file.`
   - `skills/craftapps/SKILL.md:76-90` (bridge table): add
     `| craft-anything | no bridge flag; \`--inbox DIR\` passes questions and approvals to the open app |`
     before the pdfcraft row.
   - `skills/craftapps/routing.md`: add the line
     `- how an app works / rebuild an app → craft-anything`
     after the soundcraft line.
   → Verify: `nix build .#checks.x86_64-linux.skill` passes;
   `wc -c skills/craftapps/routing.md` stays under about 900 bytes.
   Traps:
   - The `skill` check fails on a description over 1,024 characters, an
     unquoted description, or `<`, `>` or `"` in it.
   - `routing.md` has no frontmatter and must stay short (it loads every
     session).

5. Docs.
   - `flake.nix:2`: "13 pure-Rust creative apps" → "14".
   - `README.md`:
     - 5, 7, 79 and 545: thirteen → fourteen;
     - the app table at 9-25: add the row `| \`craft-anything\` | — | Study how software works and craft your own |`,
       in the table's own order and column style (read it first).
   - `llms.txt`:
     - 3: thirteen → fourteen;
     - 8: add `craft-anything (study and rebuild software)` to the app names
       line;
     - add it to any app table further down, if there is one.
   - `AGENTS.md`:
     - 8 and 13: thirteen → fourteen;
     - layout rule, around lines 60-67: replace "whose executable is
       `Contents/MacOS/<Title>`" and the #30 sentence with: the executable
       is the bundle's `CFBundleExecutable`, which `package.nix` reads
       from `Info.plist` (the `.app` name can differ, for example
       `Craft Anything.app` runs `craft-anything`), and `Contents/MacOS`
       may also hold the CLI;
     - 85: "a 14th app" → "a 15th app";
     - 115: `(\`lib.toUpper name\`)` → `(\`lib.toUpper name\`, hyphens
       turned into underscores)`.
   → Verify: `grep -rn -i thirteen README.md llms.txt AGENTS.md flake.nix`
   returns nothing; `nix fmt` changes nothing.
   Traps:
   - No narrating comments.
   - Keep the docs' existing line wrapping.

## Tests

- `nix flake check -L` passes on x86_64-linux. It builds all fourteen and
  runs `cli`, `mcp` (craft-anything included), `skill`, `module`,
  `hm-module` and `darwin-module`.
- `python3 scripts/update.py --self-test` passes.
- `nix run nixpkgs#actionlint -- .github/workflows/*.yml` passes. No
  workflow changes are expected.
- The `drvPath`s of the thirteen existing Linux packages are unchanged
  (step 2).
- On a real session, `timeout 8 ./result/bin/craft-anything` exits 124,
  with no missing-library panic.
- CI passes on ubuntu-latest, ubuntu-24.04-arm and macos-latest.

## Rollback

Revert the squash commit. `apps.json` loses the entry, the builder returns
to the #30 path and the old variable name, and consumers drop the package
and its MCP entry on their next lock bump. Check `~/.claude.json` on p620 and razer afterwards: if the
`craft-anything` MCP entry is still there, remove it by hand.
