# nix-craftapps

Install the [ArtCraft](https://getartcraft.com/apps) Crafting Apps with Nix.

[storytold](https://github.com/storytold) makes twelve native creative apps,
written in pure Rust. Each is an open-source, clean-room take on a familiar
professional tool. This flake packages all twelve for Linux. It gives you
packages to run directly, a **NixOS module** and a **Home Manager module**,
and you choose which apps to install.

| App           | Familiar as   | What it does                       |
| ------------- | ------------- | ---------------------------------- |
| `photocraft`  | Photoshop     | Image editing                      |
| `vectorcraft` | Illustrator   | Vector illustration                |
| `lightcraft`  | Lightroom     | Photo library and raw processing   |
| `pdfcraft`    | Acrobat       | Read, organize and edit PDFs       |
| `effectcraft` | After Effects | Motion graphics and visual effects |
| `designcraft` | InDesign      | Page layout and publishing         |
| `filmcraft`   | Premiere Pro  | Video editing                      |
| `gridcraft`   | Excel         | Spreadsheets                       |
| `soundcraft`  | Pro Tools     | Audio recording and editing        |
| `cadcraft`    | AutoCAD       | CAD and drafting                   |
| `wordcraft`   | Word          | Word processing                    |
| `deckcraft`   | PowerPoint    | Presentations and slide shows      |

Every app installs two commands: the GUI (`photocraft`) and a command-line
companion for scripting (`photocraft-cli`). It also installs a desktop
launcher entry and icons.

> **Early software.** The apps are pre-1.0 and storytold releases them daily.
> Expect rough edges. Your `flake.lock` keeps you on a version you know works
> until you choose to update.

## Contents

- [Requirements](#requirements)
- [Quick start: try an app without installing](#quick-start-try-an-app-without-installing)
- [Install on NixOS](#install-on-nixos)
- [Install with Home Manager](#install-with-home-manager)
- [Choosing apps](#choosing-apps)
- [Option reference](#option-reference)
- [Fonts](#fonts)
- [Updating](#updating)
- [Uninstalling](#uninstalling)
- [Troubleshooting](#troubleshooting)
- [How it works](#how-it-works)

## Requirements

- Linux on **x86_64** or **aarch64**. storytold publishes no Linux builds for
  other platforms.
- Nix with flakes enabled. If `nix flake --help` fails, add
  `experimental-features = nix-command flakes` to `~/.config/nix/nix.conf`,
  or to `/etc/nix/nix.conf` on a multi-user install.
- A graphical session, Wayland or X11. **On NixOS** the GPU needs nothing
  extra. **On other distributions** one extra step is needed; see
  [docs/GPU.md](docs/GPU.md).

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

To have all twelve in a temporary shell:

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

## Install with Home Manager

The Home Manager module installs apps for one user, with no root access
needed for the apps themselves. It has the same options as the NixOS module,
apart from `linkFonts` (see [Fonts](#fonts)).

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

Both work the same in the NixOS and Home Manager modules.

## Option reference

All options live under `programs.craftapps`.

| Option                | Type    | Default      | Description                                                       |
| --------------------- | ------- | ------------ | ----------------------------------------------------------------- |
| `enable`              | bool    | `false`      | Turn the module on. Nothing is installed without it.              |
| `enableAll`           | bool    | `false`      | Default for every `apps.<name>.enable`.                           |
| `apps.<name>.enable`  | bool    | `enableAll`  | Install (`true`) or leave out (`false`) one app.                  |
| `apps.<name>.package` | package | this flake's | Use a different build, for example one wrapped with nixGL.        |
| `linkFonts`           | bool    | `true`       | **NixOS only.** Provide `/usr/share/fonts` (see [Fonts](#fonts)). |

`<name>` is any app from the table at the top.

Without the modules, `overlays.default` adds `pkgs.craftapps.<name>`, plus
`pkgs.craftapps.craftapps-all` with every app. For example:

```nix
nixpkgs.overlays = [ inputs.nix-craftapps.overlays.default ];
environment.systemPackages = [ pkgs.craftapps.photocraft ];
```

## Fonts

The apps' text tools look for fonts in **`/usr/share/fonts` only**. They do
not use fontconfig. Most distributions have that folder. NixOS does not.

| You are on                     | What to do                                                     |
| ------------------------------ | -------------------------------------------------------------- |
| NixOS, using the NixOS module  | Nothing. `linkFonts = true` is the default.                    |
| NixOS, using only Home Manager | Enable the NixOS module with `linkFonts = true` (see setup A). |
| Another distribution           | Nothing. `/usr/share/fonts` already exists.                    |

With `linkFonts`, the module sets `fonts.fontDir.enable = true` and links
`/usr/share/fonts` to `/run/current-system/sw/share/X11/fonts`. Every font in
your `fonts.packages` becomes visible to the apps.

## Updating

Your `flake.lock` pins the app versions. To move to the newest releases:

```sh
nix flake update nix-craftapps
```

Then rebuild (`nixos-rebuild switch` or `home-manager switch`).

This repository checks storytold's releases every day. When a release is
out, a pull request adds it to `apps.json`, and CI builds and tests every app
on both architectures before the change is merged.

To go back, run `git checkout flake.lock` before rebuilding. On NixOS you can
also boot the previous generation.

## Uninstalling

- **NixOS or Home Manager:** set `programs.craftapps.enable = false`, or
  remove the block, then rebuild.
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
pinned version. storytold publishes x86_64 and aarch64 builds for Linux only.
Check the spelling too: names are lower case, like `photocraft`.

**An update broke an app.** Report it upstream at
`https://github.com/storytold/<app>/issues`. Meanwhile, roll back as
described in [Updating](#updating), or pin one app to an older build with
`apps.<name>.package`.

## How it works

- **`apps.json`** lists each app's version, release tag, and download URL and
  hash for each architecture. Nix refuses any download whose hash doesn't
  match.
- **`package.nix`** is one generic builder for every app.
  - It unpacks storytold's official Linux release tarball.
  - It uses `autoPatchelfHook` to point the binaries at Nix's glibc and ALSA.
  - It puts the libraries the apps load at startup on their library path:
    OpenGL, Vulkan, Wayland, X11, xkbcommon and D-Bus.
  - It installs the binaries, the desktop file, icons, metainfo and MIME
    types.
- **`modules/`** holds the NixOS and Home Manager modules, which share their
  option definitions.
- **`scripts/update.py`** checks GitHub for new releases and refreshes
  `apps.json`. A daily GitHub Actions job runs it.

These are upstream's prebuilt binaries, not source builds: the
`sourceProvenance` in each package's `meta` says `binaryNativeCode`. Building
from source would mean compiling twelve large Rust workspaces on every daily
release.

To work on this repository, start with [AGENTS.md](AGENTS.md). GPU details
are in [docs/GPU.md](docs/GPU.md).

## License

The packaging in this repository is MIT. The apps are dual-licensed MIT or
Apache-2.0 by storytold, and their bundled fonts are under the SIL Open Font
License (see each package's `share/doc/<app>/`).
