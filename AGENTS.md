# AGENTS.md

Guidance for AI coding agents, and for people, working on this repository.
For using the flake, read [README.md](README.md).

## What this repository is

A Nix flake that packages the thirteen storytold "Craft" apps from their
**prebuilt** releases: the Linux tarballs, and on macOS the universal DMG plus
the separate CLI zip. It does not build from source. The outputs are:

- one package per app, for x86_64-linux, aarch64-linux and aarch64-darwin;
- `default`, which is all thirteen apps;
- an overlay;
- a NixOS module, a nix-darwin module and a Home Manager module, all under
  `programs.craftapps`;
- checks.

## Layout

```text
apps.json                 registry: version, tag, url + SRI hash per system (+ cli on darwin), per app
package.nix               the ONE generic builder (Linux: autoPatchelfHook + wrapper; darwin: undmg + unzip)
default.nix               { pkgs }: maps apps.json → packages, + craftapps-all
flake.nix                 outputs; checks build every app, test each CLI and MCP server, eval the modules
modules/common.nix        shared options (enable, enableAll, apps.<n>.{enable,package,mcp.args}, mcp.*)
modules/system.nix        NixOS + nix-darwin: systemPackages, /etc/craftapps/mcp.json, HM sharedModules
modules/nixos.nix         system.nix + linkFonts (fonts.fontDir + /usr/share/fonts link)
modules/darwin.nix        system.nix; no linkFonts (macOS apps read the system font folders)
modules/home-manager.nix  home.packages, programs.mcp; no linkFonts (HM cannot write /usr/share)
modules/skill.nix         installs the skill into every HM agent with a skills option
skills/craftapps/SKILL.md agent skill installed by skill.enable
skills/craftapps/routing.md  Claude Code rule (~/.claude/rules/craftapps.md), loaded every session
scripts/update.py         refreshes apps.json from GitHub releases (stdlib only)
.github/workflows/ci.yml      nix flake check on x86_64-linux, aarch64-linux and aarch64-darwin runners
.github/workflows/update.yml  daily update.py → flake check → PR → dispatch ci.yml
```

## Commands

```sh
nix flake check -L                  # builds all 13, runs the cli, mcp, skill, (darwin-)module + hm-module checks
nix build .#photocraft              # one app
nix fmt                             # nixfmt
python3 scripts/update.py --self-test   # offline tests of the updater
python3 scripts/update.py [app ...]     # refresh apps.json (downloads tarballs)
python3 scripts/update.py --check       # exit 1 if anything is behind upstream
nix run nixpkgs#actionlint -- .github/workflows/*.yml
```

Before you commit, run `nix flake check` and the updater's `--self-test`. If
you changed a workflow, run `actionlint` too.

## Rules

- **Never hand-edit versions or hashes in `apps.json`.** Run
  `scripts/update.py`. It reads the release from GitHub and hashes the actual
  download with `nix store prefetch-file`.
- **Keep one generic builder.** Per-app logic belongs in `apps.json` data, not
  in `if name == …` branches in `package.nix`. Every app so far has the
  identical tarball layout: `bin/<app>`, `bin/<app>-cli`, and
  `share/{applications,icons,metainfo,mime,doc}`. On macOS every app has a
  DMG holding one `<Title>.app`, and a zip holding
  `<app>-cli-<version>-macos-universal/<app>-cli`.
- **The modules take packages from this flake** (`craftapps pkgs`), not from
  `pkgs.craftapps`. Consumers must not need the overlay.
- **`apps.<name>.enable` defaults to `enableAll`.** It must not be OR-ed with
  it, or excluding an app with `enableAll = true` stops working. The `module`
  check in `flake.nix` tests exactly this.
- **Every system, always.** `update.py` refuses a release that lacks a
  system the previous entry had. That's deliberate, because assets often
  upload one at a time. Don't relax it to make an update pass. A darwin
  entry needs both the DMG and the CLI zip.
- **No x86_64-darwin.** The DMGs are universal, but nixpkgs dropped
  x86_64-darwin in 26.11, so the flake cannot evaluate it.
- **Python is stdlib only.** The update workflow runs it on a bare runner.
- **Comments:** no narrating comments. Explain only a non-obvious why, like
  the comments on `runtimeDependencies` and the skip-lib-check wrapper.

## Adding a new Craft app

When storytold publishes a 14th app:

1. Add it to the `APPS` table in `scripts/update.py` with a title and a
   one-line description.
2. Run `python3 scripts/update.py <newapp>`. It writes the `apps.json` entry.
3. Run `nix build .#<newapp>`. autoPatchelf must report `0 dependencies could
   not be satisfied`, and `<newapp>-cli --version` must print the version.
   On a Mac, `codesign --verify --deep --strict result/Applications/*.app`
   must pass too.
   Also check that `<newapp>-cli mcp` answers `initialize` headless; the
   `mcp` check does this.
4. Launch the GUI on a real session, on Linux and on a Mac if you can. Run
   `timeout 8 ./result/bin/<newapp>`; exit status 124 means it stayed up. If it panics about a missing library,
   add that library to `runtimeDependencies` in `package.nix`.
5. Add it to the app tables in `README.md` and `llms.txt`. If it has its
   own GPU switches (`strings` the binary for `*_GPU*`), note them in
   `docs/GPU.md`.
6. Add the app to `skills/craftapps/SKILL.md`: its bridge flag, its row in
   the routing table, and its intents in the `description`. The `skill`
   check keeps that under 1,024 characters. Add it to
   `skills/craftapps/routing.md` too, and keep that file short.

## Traps already found

- **Missing graphics libraries.** The GUIs `dlopen()` their graphics stack,
  so it never shows up in the ELF `NEEDED` list. `runtimeDependencies`
  covers it. A build can pass while the GUI fails to start, which is why
  step 4 above is manual.
- **PhotoCraft's own library check.** PhotoCraft runs `ldconfig -p` before it
  starts and refuses to launch on NixOS. The wrapper sets
  `<APP>_SKIP_LIB_CHECK=1` for every app (`lib.toUpper name`), which also
  covers any app that copies the check later.
- **Fonts.** On Linux the text tools read `/usr/share/fonts` only, with no
  fontconfig. On macOS they read `/System/Library/Fonts`, `/Library/Fonts`
  and `~/Library/Fonts`, so the darwin module has no `linkFonts`. On NixOS,
  `/run/current-system/sw/share/X11/fonts` exists only when
  `fonts.fontDir.enable` is on. `linkFonts` sets that.
- **`<app>-cli --help` is not consistent.** Several CLIs print usage and exit
  1 or 2. `--version` exits 0 everywhere, and the `cli` check uses it.
- **CI on update PRs.** A PR opened with `GITHUB_TOKEN` does not trigger
  `pull_request` workflows, so `update.yml` dispatches `ci.yml` on the PR
  branch itself. Once every runner passes, the `automerge` job in `ci.yml`
  squash-merges the PR; a failure leaves it open.
- **Code signing on macOS.** The `.app` bundles and CLIs are signed and
  notarized upstream. `package.nix` copies them untouched and sets
  `dontFixup` on darwin, because stripping breaks the signature. Never patch
  or re-sign them.
- **GPU.** All apps render through wgpu (egui/eframe). On Linux: Vulkan
  first, then GLES through EGL. On macOS: Metal, nothing to set up. Drivers are found only in `/run/opengl-driver`.
  `WGPU_BACKEND=gl` is honoured (verified). The modules must never set
  `hardware.graphics`, `hardware.nvidia` or any driver option, and
  `docs/GPU.md` promises users exactly that. If you change GPU-related
  behaviour, update that page's tables and its "What has been tested"
  section.
- **MCP.** The servers are stdio (`<app>-cli mcp`), so there is no service.
  Never write `/etc/claude-code/managed-mcp.json`; it takes exclusive
  control of MCP. Defaults that are not headless go in `mcpArgs` in
  `modules/common.nix`. pdfcraft and lightcraft default to `--compact`
  there (163 and 388 tools otherwise).
- **Launching a GUI.** Running a GUI with an unknown flag such as `--help`
  opens a window instead of printing help. Use the `-cli` binary for
  anything headless.

## Commits and PRs

- **Commit messages:** Conventional Commits (`feat:`, `fix:`, `chore:`,
  `docs:`). Update PRs from the workflow are titled `chore: update Craft
  apps`.
- **Before merging:** CI must pass on all three runners.
