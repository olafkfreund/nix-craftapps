# nix-craftapps

Install the [ArtCraft](https://getartcraft.com/apps) Crafting Apps with Nix.

[storytold](https://github.com/storytold) makes thirteen native creative apps,
written in pure Rust. Each is an open-source, clean-room take on a familiar
professional tool. This flake packages all thirteen for Linux and for macOS on
Apple silicon. It gives you packages to run directly, a **NixOS module**, a
**nix-darwin module** and a **Home Manager module**, and you choose which apps
to install.

| App           | Familiar as   | What it does                       |
| ------------- | ------------- | ---------------------------------- |
| `photocraft`  | Photoshop     | Image editing                      |
| `vectorcraft` | Illustrator   | Vector illustration                |
| `lightcraft`  | Lightroom     | Photo library and raw processing   |
| `pdfcraft`    | Acrobat       | Read, organize and edit PDFs       |
| `effectcraft` | After Effects | Motion graphics and visual effects |
| `designcraft` | InDesign      | Page layout and publishing         |
| `filmcraft`   | Premiere Pro  | Video editing                      |
| `figcraft`    | Figma         | Interface design and prototyping   |
| `gridcraft`   | Excel         | Spreadsheets                       |
| `soundcraft`  | Pro Tools     | Audio recording and editing        |
| `cadcraft`    | AutoCAD       | CAD and drafting                   |
| `wordcraft`   | Word          | Word processing                    |
| `deckcraft`   | PowerPoint    | Presentations and slide shows      |

Every app installs two commands: the GUI (`photocraft`) and a command-line
companion for scripting (`photocraft-cli`). On Linux it also installs a
desktop launcher entry and icons; on macOS it installs the app bundle
(`PhotoCraft.app`).

> **Early software.** The apps are pre-1.0 and storytold releases them daily.
> Expect rough edges. Your `flake.lock` keeps you on a version you know works
> until you choose to update.

## Contents

- [Requirements](#requirements)
- [Quick start: try an app without installing](#quick-start-try-an-app-without-installing)
- [Install on NixOS](#install-on-nixos)
- [Install on macOS with nix-darwin](#install-on-macos-with-nix-darwin)
- [Install with Home Manager](#install-with-home-manager)
- [Choosing apps](#choosing-apps)
- [Option reference](#option-reference)
- [MCP servers](#mcp-servers)
- [Fonts](#fonts)
- [Updating](#updating)
- [Uninstalling](#uninstalling)
- [Troubleshooting](#troubleshooting)
- [How it works](#how-it-works)

## Requirements

- Linux on **x86_64** or **aarch64**, or macOS 11 or later on **Apple
  silicon** (aarch64-darwin). Intel Macs are not supported: storytold's DMGs
  are universal, but nixpkgs no longer supports x86_64-darwin.
- Nix with flakes enabled. If `nix flake --help` fails, add
  `experimental-features = nix-command flakes` to `~/.config/nix/nix.conf`,
  or to `/etc/nix/nix.conf` on a multi-user install.
- A graphical session, Wayland or X11. **On NixOS** the GPU needs nothing
  extra. **On other distributions** one extra step is needed; see
  [docs/GPU.md](docs/GPU.md). **On macOS** nothing is needed.

## Quick start: try an app without installing

```sh
nix run github:olafkfreund/nix-craftapps#photocraft
```

Swap in any app name from the table. To get both the GUI and its CLI in a
temporary shell:

```sh
nix shell github:olafkfreund/nix-craftapps#deckcraft
deckcraft-cli --version
```

To have all thirteen in a temporary shell:

```sh
nix shell github:olafkfreund/nix-craftapps
```

Nothing is installed. The apps disappear at the next garbage collection.

## Install on NixOS

### 1. Add the flake input

In your system `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-craftapps = {
      url = "github:olafkfreund/nix-craftapps";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nix-craftapps, ... }: {
    nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        nix-craftapps.nixosModules.default
      ];
    };
  };
}
```

`inputs.nixpkgs.follows` makes the apps use your system's libraries, so no
second copy of nixpkgs is downloaded.

### 2. Pick your apps

In `configuration.nix`:

```nix
{
  programs.craftapps = {
    enable = true;
    apps.photocraft.enable = true;
    apps.vectorcraft.enable = true;
    apps.pdfcraft.enable = true;
  };
}
```

To install everything instead, see [Choosing apps](#choosing-apps).

### 3. Rebuild

```sh
sudo nixos-rebuild switch --flake .#my-machine
```

The apps appear in your launcher. The NixOS module also sets up the font
directory the apps need; see [Fonts](#fonts).

## Install on macOS with nix-darwin

Add the input as in [Install on NixOS](#1-add-the-flake-input), then import
the module in your `darwinConfigurations`:

```nix
{
  outputs = { nix-darwin, nix-craftapps, ... }: {
    darwinConfigurations.my-mac = nix-darwin.lib.darwinSystem {
      modules = [
        ./darwin-configuration.nix
        nix-craftapps.darwinModules.default
      ];
    };
  };
}
```

Pick your apps with the same options as on NixOS:

```nix
{
  programs.craftapps = {
    enable = true;
    apps.photocraft.enable = true;
    apps.figcraft.enable = true;
  };
}
```

Rebuild with `sudo darwin-rebuild switch --flake .#my-mac`. nix-darwin puts
the apps in `/Applications/Nix Apps`, and `photocraft` and `photocraft-cli` on
your `PATH`.

The apps are storytold's signed and notarized builds, copied unchanged, so
Gatekeeper opens them without a warning. macOS has no `/usr/share/fonts`
problem and needs no GPU setup, so the nix-darwin module has no `linkFonts`.

## Install with Home Manager

The Home Manager module installs apps for one user, with no root access
needed for the apps themselves. It has the same options as the NixOS module,
apart from `linkFonts` (see [Fonts](#fonts)). It works on macOS too: Home
Manager puts the app bundles in `~/Applications/Home Manager Apps`.

Choose the section that matches how you run Home Manager.

### A. Home Manager inside your NixOS configuration

Add the input as in [Install on NixOS](#1-add-the-flake-input), then import
the module for the user:

```nix
# in your NixOS modules, with home-manager.nixosModules.home-manager imported
{
  home-manager.sharedModules = [ inputs.nix-craftapps.homeManagerModules.default ];

  home-manager.users.alice = {
    programs.craftapps = {
      enable = true;
      apps.wordcraft.enable = true;
      apps.gridcraft.enable = true;
    };
  };
}
```

Rebuild with `sudo nixos-rebuild switch --flake .#my-machine`.

With nix-darwin, the same block goes in your nix-darwin modules, with
`home-manager.darwinModules.home-manager` imported, and you rebuild with
`darwin-rebuild`. macOS needs no font directory.

**On NixOS you still need the font directory.** Also add
`programs.craftapps = { enable = true; linkFonts = true; };` to the system
configuration, with no apps enabled there, or the apps' text tools find no
fonts.

### B. Standalone Home Manager

Your `~/.config/home-manager/flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-craftapps = {
      url = "github:olafkfreund/nix-craftapps";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, nix-craftapps, ... }: {
    homeConfigurations.alice = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        nix-craftapps.homeManagerModules.default
        ./home.nix
      ];
    };
  };
}
```

Your `~/.config/home-manager/home.nix`:

```nix
{
  home.username = "alice";
  home.homeDirectory = "/home/alice";
  home.stateVersion = "25.05";

  programs.craftapps = {
    enable = true;
    apps.photocraft.enable = true;
    apps.lightcraft.enable = true;
  };
}
```

Apply it:

```sh
home-manager switch --flake ~/.config/home-manager#alice
```

If you don't have the `home-manager` command yet, run it once with
`nix run github:nix-community/home-manager -- switch --flake ~/.config/home-manager#alice`.

### C. Home Manager on Ubuntu, Fedora, Arch and other distributions

Use setup B, then add the GPU step below. Fonts need no extra work, because
your distribution already provides `/usr/share/fonts`.

#### GPU drivers on other distributions

Programs built by Nix cannot find your distribution's OpenGL and Vulkan
drivers on their own, so you need one extra step. There are two ways:

- **Recommended:** add `targets.genericLinux.enable = true;` to `home.nix`,
  then run the `sudo …/non-nixos-gpu-setup` command that `home-manager
  switch` prints, once. It adds `/run/opengl-driver` and one tmpfiles file,
  and touches nothing your distribution uses.
- **No sudo:** wrap the apps with nixGL. This changes nothing on the system.

**NVIDIA's proprietary driver needs its exact version in `home.nix`,** and
that version has to be updated whenever your distribution updates the
driver.

The full steps, what each one changes, how to undo it, hybrid laptops, VMs
and per-launch GPU switches are in **[docs/GPU.md](docs/GPU.md)**.

## Choosing apps

Each app has its own switch, `apps.<name>.enable`. There are two ways to use
it.

**Pick the apps you want.** Leave `enableAll` off, which is the default, and
turn single apps on:

```nix
programs.craftapps = {
  enable = true;
  apps.photocraft.enable = true;
  apps.deckcraft.enable = true;
};
```

**Take everything, minus a few.** `enableAll` sets the default for every
app's switch, so you list only the exceptions:

```nix
programs.craftapps = {
  enable = true;
  enableAll = true;
  apps.soundcraft.enable = false;
  apps.filmcraft.enable = false;
};
```

Both work the same in the NixOS, nix-darwin and Home Manager modules.

## Option reference

All options live under `programs.craftapps`.

| Option                 | Type            | Default      | Description                                                                      |
| ---------------------- | --------------- | ------------ | -------------------------------------------------------------------------------- |
| `enable`               | bool            | `false`      | Turn the module on. Nothing is installed without it.                             |
| `enableAll`            | bool            | `false`      | Default for every `apps.<name>.enable`.                                          |
| `apps.<name>.enable`   | bool            | `enableAll`  | Install (`true`) or leave out (`false`) one app.                                 |
| `apps.<name>.package`  | package         | this flake's | Use a different build, for example one wrapped with nixGL.                       |
| `linkFonts`            | bool            | `true`       | **NixOS only.** Provide `/usr/share/fonts` (see [Fonts](#fonts)).                |
| `mcp.enable`           | bool            | `false`      | Define an MCP server for every enabled app (see [MCP servers](#mcp-servers)).    |
| `apps.<name>.mcp.args` | list of strings | `[ "mcp" ]`  | Arguments for `<name>-cli` as an MCP server. VectorCraft: `--headless`; PdfCraft and LightCraft: `--compact`. |
| `mcp.servers`          | attrs           | read-only    | The resulting servers: one `{ command, args }` per enabled app.                  |
| `skill.enable`         | bool            | `false`      | Install the agent skill (see [Agent skill](#agent-skill)).                       |

On NixOS and nix-darwin with `mcp.enable`, the same servers are written to
`/etc/craftapps/mcp.json`. Home Manager does not write that file.

`<name>` is any app from the table at the top.

Without the modules, `overlays.default` adds `pkgs.craftapps.<name>`, plus
`pkgs.craftapps.craftapps-all` with every app. For example:

```nix
nixpkgs.overlays = [ inputs.nix-craftapps.overlays.default ];
environment.systemPackages = [ pkgs.craftapps.photocraft ];
```

## MCP servers

Every app has a built-in [MCP](https://modelcontextprotocol.io) server:
`<app>-cli mcp`, over stdio. The client starts it, so there is no service to
run. Set `programs.craftapps.mcp.enable = true` and the module defines one
server for each enabled app.

**Home Manager.** The module sets `programs.mcp.servers`. Turn on your
client's integration to read them:

```nix
programs.craftapps.mcp.enable = true;
programs.claude-code.enableMcpIntegration = true;
```

Codex, Copilot CLI and other clients have the same `enableMcpIntegration`
switch; Cursor has it per profile (`programs.cursor.profiles.<name>`).
This needs a Home Manager new enough to have `programs.mcp`; on older
versions the module skips it. To check that Claude Code sees the servers,
run `claude mcp list`.

**NixOS or nix-darwin without Home Manager.** The module writes
`/etc/craftapps/mcp.json`.
Add its servers to Claude Code per user, and run this again after each
rebuild that updates the apps, because the entries hold store paths:

```bash
jq -r '.mcpServers | to_entries[] | "\(.key)\t\(.value | tojson)"' \
  /etc/craftapps/mcp.json |
while IFS=$'\t' read -r name json; do
  claude mcp remove --scope user "$name" 2>/dev/null || true
  claude mcp add-json --scope user "$name" "$json"
done
```

With the NixOS or nix-darwin module and Home Manager together, every Home
Manager user also gets the servers through `programs.mcp`.

The module does not write `/etc/claude-code/managed-mcp.json`. Claude Code
treats that file as exclusive control of MCP and ignores users' own servers,
and its managed policy accepts only `https` servers.

PdfCraft and LightCraft list hundreds of tools, so the module starts both
with `--compact`. PdfCraft then lists a core set plus `tool_search` and
`tool_call`; LightCraft lists its helper tools and runs every other command
through `run_command`. For the full list, set
`programs.craftapps.apps.<app>.mcp.args = [ "mcp" ];`.

VectorCraft's default mode sends tool calls to a running app on
`127.0.0.1:7979`, so the module starts it with `--headless`. To make any app
drive a running GUI instead, or to add file-root flags, set the arguments:

```nix
programs.craftapps.apps.photocraft.mcp.args = [ "mcp" "--bridge" "127.0.0.1:<port>" ];
```

The entries use store paths. Home Manager refreshes them on every switch;
anything you copied from `/etc/craftapps/mcp.json` by hand goes stale after a
rebuild that updates the apps.

### Agent skill

```nix
programs.craftapps.skill.enable = true;
```

This installs one skill, `craftapps`, for every Home Manager agent that has a
`programs.<agent>.skills` option: Claude Code, Codex, opencode, Crush, Copilot
CLI and Antigravity CLI. It tells agents which app to use for each request
(for example .pptx → DeckCraft, .docx → WordCraft, .xlsx → GridCraft), so
they use the installed apps instead of writing files by hand. It also covers
how to use the apps headless, how to connect to a running app, and the file
roots. For Claude Code it also installs `~/.claude/rules/craftapps.md`, a
short routing rule loaded in every session (about 200 tokens), unless you set
`programs.claude-code.rulesDir`. It is independent of `mcp.enable`. With the
NixOS or nix-darwin module, it applies to every Home Manager user.

If your own `programs.<agent>.skills` is a path (a whole skills directory),
evaluation fails with a type error on `programs.<agent>.skills` when this is
on. Make it an attribute set (`skills.mine = ./mine;`) instead.

## Fonts

On Linux, the apps' text tools look for fonts in **`/usr/share/fonts`
only**. They do not use fontconfig. Most distributions have that folder.
NixOS does not. On macOS they use the system font folders
(`/System/Library/Fonts`, `/Library/Fonts` and `~/Library/Fonts`).

| You are on                     | What to do                                                     |
| ------------------------------ | -------------------------------------------------------------- |
| NixOS, using the NixOS module  | Nothing. `linkFonts = true` is the default.                    |
| NixOS, using only Home Manager | Enable the NixOS module with `linkFonts = true` (see setup A). |
| Another distribution           | Nothing. `/usr/share/fonts` already exists.                    |
| macOS                          | Nothing. The apps use the macOS font folders.                  |

With `linkFonts`, the module sets `fonts.fontDir.enable = true` and links
`/usr/share/fonts` to `/run/current-system/sw/share/X11/fonts`. Every font in
your `fonts.packages` becomes visible to the apps.

## Updating

Your `flake.lock` pins the app versions. To move to the newest releases:

```sh
nix flake update nix-craftapps
```

Then rebuild (`nixos-rebuild switch`, `darwin-rebuild switch` or
`home-manager switch`).

This repository checks storytold's releases every day. When a release is
out, a pull request adds it to `apps.json`, and CI builds and tests every app
on x86_64 and aarch64 Linux and on Apple silicon macOS before the change is
merged.

To go back, run `git checkout flake.lock` before rebuilding. On NixOS you can
also boot the previous generation; with nix-darwin, run
`sudo darwin-rebuild --rollback`.

## Uninstalling

- **NixOS, nix-darwin or Home Manager:** set
  `programs.craftapps.enable = false`, or remove the block, then rebuild.
- **`nix run` / `nix shell`:** nothing to remove. The next
  `nix-collect-garbage` frees the space.
- **Fonts:** turning the NixOS module off stops it managing the
  `/usr/share/fonts` link, but doesn't delete it. Remove it with
  `sudo rm /usr/share/fonts`.

## Troubleshooting

**The app doesn't open, or prints `Failed to create … adapter`, `no Vulkan
driver` or `could not open display`.**

- Work through [docs/GPU.md](docs/GPU.md#checking-your-setup). It has
  read-only checks for every platform.
- On NixOS, check that `hardware.graphics.enable = true` is set.
- To rule out a GPU driver bug, force software rendering for one launch:
  `WGPU_BACKEND=gl LIBGL_ALWAYS_SOFTWARE=1 photocraft`.
- To test without the GPU, try the CLI first. `photocraft-cli --version`
  needs no display.

**Text tools show no fonts, or the font list is empty.** `/usr/share/fonts`
is missing. Check with `ls /usr/share/fonts`, then see [Fonts](#fonts).

**PhotoCraft says required libraries are missing.** PhotoCraft looks for its
graphics libraries with `ldconfig`, which cannot see libraries a Nix package
carries. The packaged launcher sets `PHOTOCRAFT_SKIP_LIB_CHECK=1` to skip
that check; the libraries themselves load fine. If you start the raw binary
some other way, set that variable yourself.

**`error: attribute '<app>' missing`, or `does not provide attribute
'packages.<system>.<app>'`.** The app has no build for your platform in the
pinned version. The flake has x86_64-linux, aarch64-linux and aarch64-darwin
builds; there are none for Intel Macs. Check the spelling too: names are lower
case, like `photocraft`.

**An update broke an app.** Report it upstream at
`https://github.com/storytold/<app>/issues`. Meanwhile, roll back as
described in [Updating](#updating), or pin one app to an older build with
`apps.<name>.package`.

## How it works

- **`apps.json`** lists each app's version, release tag, and download URL and
  hash for each architecture. Nix refuses any download whose hash doesn't
  match.
- **`package.nix`** is one generic builder for every app.
  - On macOS it unpacks storytold's universal DMG and CLI zip, puts the app
    bundle in `Applications/` and both commands in `bin/`, and changes
    nothing inside them, so upstream's code signature stays valid.
  - On Linux it unpacks storytold's official release tarball.
  - It uses `autoPatchelfHook` to point the binaries at Nix's glibc and ALSA.
  - It puts the libraries the apps load at startup on their library path:
    OpenGL, Vulkan, Wayland, X11, xkbcommon and D-Bus.
  - It installs the binaries, the desktop file, icons, metainfo and MIME
    types.
- **`modules/`** holds the NixOS, nix-darwin and Home Manager modules, which
  share their option definitions.
- **`scripts/update.py`** checks GitHub for new releases and refreshes
  `apps.json`. A daily GitHub Actions job runs it.
  It opens a PR that merges itself once CI passes on every platform.

These are upstream's prebuilt binaries, not source builds: the
`sourceProvenance` in each package's `meta` says `binaryNativeCode`. Building
from source would mean compiling thirteen large Rust workspaces on every daily
release.

To work on this repository, start with [AGENTS.md](AGENTS.md). GPU details
are in [docs/GPU.md](docs/GPU.md).

## License

The packaging in this repository is MIT. The apps are dual-licensed MIT or
Apache-2.0 by storytold, and their bundled fonts are under the SIL Open Font
License (see each package's `share/doc/<app>/`).
