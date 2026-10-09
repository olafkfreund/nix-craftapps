# AGENTS.md

Guidance for AI coding agents, and for people, working on this repository.
For using the flake, read [README.md](README.md).

## What this repository is

A Nix flake that packages the twelve storytold "Craft" apps from their
**prebuilt** Linux release tarballs. It does not build from source. The
outputs are:

- one package per app;
- `default`, which is all twelve apps;
- an overlay;
- a NixOS module and a Home Manager module, both under `programs.craftapps`;
- checks.

## Layout

```text
apps.json                 registry: version, tag, url + SRI hash per system, per app
package.nix               the ONE generic builder (fetchurl + autoPatchelfHook + wrapper)
default.nix               { pkgs }: maps apps.json → packages, + craftapps-all
flake.nix                 outputs; checks build every app, test each CLI, eval the module
modules/common.nix        shared options (enable, enableAll, apps.<n>.{enable,package})
modules/nixos.nix         + linkFonts (fonts.fontDir + /usr/share/fonts tmpfiles link)
modules/home-manager.nix  home.packages; no linkFonts (HM cannot write /usr/share)
scripts/update.py         refreshes apps.json from GitHub releases (stdlib only)
.github/workflows/ci.yml      nix flake check on x86_64 and aarch64 runners
.github/workflows/update.yml  daily update.py → flake check → PR → dispatch ci.yml
```

## Commands

```sh
nix flake check -L                  # builds all 12, runs the CLI + module checks
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
  `share/{applications,icons,metainfo,mime,doc}`.
- **The modules take packages from this flake** (`craftapps pkgs`), not from
  `pkgs.craftapps`. Consumers must not need the overlay.
- **`apps.<name>.enable` defaults to `enableAll`.** It must not be OR-ed with
  it, or excluding an app with `enableAll = true` stops working. The `module`
  check in `flake.nix` tests exactly this.
- **Both architectures, always.** `update.py` refuses a release that lacks an
  architecture the previous entry had. That's deliberate, because assets
  often upload one at a time. Don't relax it to make an update pass.
- **Python is stdlib only.** The update workflow runs it on a bare runner.
- **Comments:** no narrating comments. Explain only a non-obvious why, like
  the comments on `runtimeDependencies` and the skip-lib-check wrapper.

## Adding a new Craft app

When storytold publishes a 13th app:

1. Add it to the `APPS` table in `scripts/update.py` with a title and a
   one-line description.
2. Run `python3 scripts/update.py <newapp>`. It writes the `apps.json` entry.
3. Run `nix build .#<newapp>`. autoPatchelf must report `0 dependencies could
   not be satisfied`, and `<newapp>-cli --version` must print the version.
4. Launch the GUI on a real session. Run `timeout 8 ./result/bin/<newapp>`;
   exit status 124 means it stayed up. If it panics about a missing library,
   add that library to `runtimeDependencies` in `package.nix`.
5. Add it to the app tables in `README.md` and `llms.txt`. If it has its
   own GPU switches (`strings` the binary for `*_GPU*`), note them in
   `docs/GPU.md`.

## Traps already found

- **Missing graphics libraries.** The GUIs `dlopen()` their graphics stack,
  so it never shows up in the ELF `NEEDED` list. `runtimeDependencies`
  covers it. A build can pass while the GUI fails to start, which is why
  step 4 above is manual.
- **PhotoCraft's own library check.** PhotoCraft runs `ldconfig -p` before it
  starts and refuses to launch on NixOS. The wrapper sets
  `<APP>_SKIP_LIB_CHECK=1` for every app (`lib.toUpper name`), which also
  covers any app that copies the check later.
- **Fonts.** The text tools read `/usr/share/fonts` only, with no
  fontconfig. On NixOS, `/run/current-system/sw/share/X11/fonts` exists only
  when `fonts.fontDir.enable` is on. `linkFonts` sets that.
- **`<app>-cli --help` is not consistent.** Several CLIs print usage and exit
  1 or 2. `--version` exits 0 everywhere, and the `cli` check uses it.
- **CI on update PRs.** A PR opened with `GITHUB_TOKEN` does not trigger
  `pull_request` workflows, so `update.yml` dispatches `ci.yml` on the PR
  branch itself.
- **GPU.** All apps render through wgpu (egui/eframe): Vulkan first, then
  GLES through EGL. Drivers are found only in `/run/opengl-driver`.
  `WGPU_BACKEND=gl` is honoured (verified). The modules must never set
  `hardware.graphics`, `hardware.nvidia` or any driver option, and
  `docs/GPU.md` promises users exactly that. If you change GPU-related
  behaviour, update that page's tables and its "What has been tested"
  section.
- **Launching a GUI.** Running a GUI with an unknown flag such as `--help`
  opens a window instead of printing help. Use the `-cli` binary for
  anything headless.

## Commits and PRs

- **Commit messages:** Conventional Commits (`feat:`, `fix:`, `chore:`,
  `docs:`). Update PRs from the workflow are titled `chore: update Craft
  apps`.
- **Before merging:** CI must pass on both architectures.
