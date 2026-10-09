# nix-craftapps

Nix packages and NixOS/Home Manager modules for the
[ArtCraft](https://getartcraft.com/apps) Crafting Apps by
[storytold](https://github.com/storytold): twelve native, pure-Rust creative
apps. Each one ships a GUI and a `<app>-cli` companion.

| Package       | What it is                                       |
| ------------- | ------------------------------------------------ |
| `photocraft`  | Photoshop-style image editor                     |
| `vectorcraft` | Illustrator-style vector illustration            |
| `lightcraft`  | Lightroom-style photo library and raw processor  |
| `pdfcraft`    | Acrobat-style PDF reader, organizer and editor   |
| `effectcraft` | After Effects-style motion graphics and VFX      |
| `designcraft` | InDesign-style page layout and publishing        |
| `filmcraft`   | Premiere-style video editor                      |
| `gridcraft`   | Excel-style spreadsheet                          |
| `soundcraft`  | Pro Tools-style audio workstation                |
| `cadcraft`    | AutoCAD-style CAD and drafting                   |
| `wordcraft`   | Word-style word processor                        |
| `deckcraft`   | PowerPoint-style presentations and slide shows   |

They are packaged from upstream's Linux release tarballs, pinned by hash in
`apps.json`. Builds are available for x86_64-linux and aarch64-linux. The
apps are pre-1.0 and change daily.

## Try one

```sh
nix run github:olafkfreund/nix-craftapps#photocraft
nix shell github:olafkfreund/nix-craftapps#deckcraft   # GUI and deckcraft-cli
```

## NixOS

```nix
{
  inputs.nix-craftapps = {
    url = "github:olafkfreund/nix-craftapps";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # in a NixOS configuration:
  imports = [ inputs.nix-craftapps.nixosModules.default ];
  programs.craftapps = {
    enable = true;
    enableAll = true;                  # or pick apps:
    apps.photocraft.enable = true;
    apps.deckcraft.enable = true;
  };
}
```

| Option                                | Default       | Meaning                                    |
| ------------------------------------- | ------------- | ------------------------------------------ |
| `programs.craftapps.enable`           | `false`       | Turn the module on                         |
| `programs.craftapps.enableAll`        | `false`       | Install all twelve apps                    |
| `programs.craftapps.apps.<n>.enable`  | `false`       | Install one app                            |
| `programs.craftapps.apps.<n>.package` | this flake's  | Override the package                       |
| `programs.craftapps.linkFonts`        | `true`        | NixOS only: provide `/usr/share/fonts`     |

**Fonts.** The apps' text tools look for fonts only in `/usr/share/fonts`
and do not use fontconfig. With `linkFonts`, the NixOS module sets
`fonts.fontDir.enable` and links that path to the system fonts.

## Home Manager

```nix
imports = [ inputs.nix-craftapps.homeManagerModules.default ];
programs.craftapps = {
  enable = true;
  apps.wordcraft.enable = true;
};
```

The options are the same as on NixOS, apart from `linkFonts`: Home Manager
cannot create `/usr/share/fonts`, so on NixOS either use the NixOS module or
provide that path some other way.

## Overlay

`overlays.default` adds `pkgs.craftapps.<app>` and `pkgs.craftapps.craftapps-all`.

## Updates

A daily workflow runs `scripts/update.py`, which reads each app's latest
release and adds new versions and their hashes to `apps.json`. The workflow
then runs `nix flake check`, which builds all twelve apps, checks each
`<app>-cli --version` and evaluates the NixOS module, and opens a PR. nixpkgs
is bumped on Mondays. To run the update locally:

```sh
python3 scripts/update.py            # all apps
python3 scripts/update.py photocraft # one app
python3 scripts/update.py --check    # exit 1 if anything is behind
```

## Notes

- **Startup check.** PhotoCraft checks its graphics libraries with
  `ldconfig -p`, which cannot see the libraries a Nix package carries, so it
  refuses to start. The wrapper sets `<APP>_SKIP_LIB_CHECK=1` on every GUI;
  the libraries load fine from the package.
- **Licences.** The apps are dual-licensed MIT/Apache-2.0 upstream. This
  packaging is MIT.
